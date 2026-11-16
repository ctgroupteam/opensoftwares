// Supabase Edge Function: send-notification
// Sends FCM HTTP v1 Data Messages signed with Google Service Account JWT

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestPayload {
  recipients?: string[]; // user_ids
  team?: string;        // 'Gulbarga' | 'Solapur' | 'Both' | 'all'
  title: string;
  body: string;
  type?: "alerts" | "reminders" | "general" | "task" | "meeting" | "collection";
  requireAck?: boolean;
  extra?: Record<string, any>;
}

// Generate Google OAuth2 Token for FCM HTTP v1
async function getGoogleAuthToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodeBase64Url = (obj: any) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const unsignedToken = `${encodeBase64Url(header)}.${encodeBase64Url(claim)}`;

  // Import private key
  const pem = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  
  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken)
  );

  const base64UrlSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const jwt = `${unsignedToken}.${base64UrlSignature}`;

  // Exchange for access token
  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResp.json();
  return tokenData.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const body: RequestPayload = await req.json();

    const serviceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getGoogleAuthToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    // Fetch target device tokens
    let query = supabase.from("crm_notifications").select("id, user_id, device_token");
    if (body.recipients && body.recipients.length > 0) {
      query = query.in("user_id", body.recipients);
    } else if (body.team && body.team !== "all" && body.team !== "Both") {
      // Find users in team
      const { data: teamUsers } = await supabase.from("crm_profiles").select("id").eq("team", body.team);
      const userIds = (teamUsers || []).map((u) => u.id);
      query = query.in("user_id", userIds);
    }

    const { data: tokens, error: tokenErr } = await query;
    if (tokenErr) throw tokenErr;

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ success: true, count: 0, message: "No device tokens found" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const invalidTokenIds: string[] = [];
    let successCount = 0;

    // Send FCM HTTP v1 messages
    for (const item of tokens) {
      const fcmMessage = {
        message: {
          token: item.device_token,
          data: {
            title: body.title,
            body: body.body,
            type: body.type || "general",
            require_ack: body.requireAck ? "true" : "false",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            ...(body.extra || {}),
          },
          android: {
            priority: "HIGH",
            notification: {
              channel_id: body.type === "alerts" ? "alerts" : (body.type === "reminders" ? "reminders" : "general"),
              default_sound: true,
              default_vibrate_timings: true,
            },
          },
        },
      };

      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(fcmMessage),
        }
      );

      if (res.ok) {
        successCount++;
      } else {
        const errJson = await res.json();
        if (
          errJson.error?.code === 404 ||
          errJson.error?.details?.some((d: any) => d.errorCode === "UNREGISTERED")
        ) {
          invalidTokenIds.push(item.id);
        }
      }
    }

    // Clean up stale tokens
    if (invalidTokenIds.length > 0) {
      await supabase.from("crm_notifications").delete().in("id", invalidTokenIds);
    }

    return new Response(
      JSON.stringify({ success: true, sent: successCount, cleaned: invalidTokenIds.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
