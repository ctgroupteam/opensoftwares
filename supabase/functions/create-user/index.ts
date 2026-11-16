// Supabase Edge Function: create-user
// Secure user creation using Supabase Service Role Key without exposing secrets to client

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Check caller is admin founder
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check role in crm_profiles
    const { data: profile } = await supabaseAdmin
      .from("crm_profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profile?.role !== "admin_founder") {
      return new Response(JSON.stringify({ error: "Forbidden: Admin Founder required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { mobile, password, name, role, team, permissions } = await req.json();
    if (!mobile || !password || !name) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const email = `${mobile}@opensoftwares.app`;

    // Create auth user
    const { data: createdAuth, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, mobile, role: role || "founder" },
    });

    if (createErr) {
      return new Response(JSON.stringify({ error: createErr.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Insert into crm_profiles
    const { error: profileErr } = await supabaseAdmin.from("crm_profiles").upsert({
      id: createdAuth.user.id,
      mobile_number: mobile,
      name,
      role: role || "founder",
      team: team || "Gulbarga",
      permissions: permissions || {
        tabs: ["home", "pipeline", "products", "profile"],
        modules: {
          tasks: { create: true, edit: true, delete: true },
          products: { create: true, edit: true, delete: true },
          leads: { create: true, edit: true, delete: true },
          partners: { create: true, edit: true, delete: true },
          collections: { create: true, edit: true, delete: true },
          meetings: { create: true, edit: true, delete: true },
          notices: { create: true, edit: true, delete: true },
        },
      },
      is_disabled: false,
      first_login_change_required: false,
    });

    if (profileErr) {
      return new Response(JSON.stringify({ error: profileErr.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ success: true, user: createdAuth.user }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

