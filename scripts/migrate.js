const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', 'secrets.env') });

async function runMigration() {
  const connectionString = process.env.DB_CONNECTION_STRING;
  if (!connectionString) {
    console.error('Missing DB_CONNECTION_STRING in secrets.env');
    process.exit(1);
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Supabase PostgreSQL database...');
    await client.connect();
    console.log('Connected successfully!');

    const sqlPath = path.join(__dirname, 'migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Executing database schema migrations (3 core tables)...');
    await client.query(sql);
    console.log('3 tables, indexes, triggers, and RLS policies created successfully!');

    // Seed Admin Founder
    const adminNumber = process.env.ADMIN_NUMBER || '9307426215';
    const adminPassword = process.env.ADMIN_PASSWORD || '#kotlin';
    const adminName = process.env.ADMIN_NAME || 'Yahya Mundewadi';

    console.log(`Seeding Admin Founder (${adminName}, ${adminNumber})...`);
    const seedRes = await client.query(
      `SELECT public.crm_seed_admin($1, $2, $3) as result;`,
      [adminNumber, adminPassword, adminName]
    );
    console.log('Admin Founder seeded:', seedRes.rows[0].result);

    // Seed 3 Software Products
    console.log('Seeding initial 3 software products...');
    const seedProducts = [
      {
        title: 'OpenSchool ERP',
        desc: 'Comprehensive cloud-based school management, student information, fee collection, attendance & parent portal system.',
        price: '180000',
        features: ['Fee Collections', 'Attendance & Timetable', 'Parent Mobile App', 'Bus Tracking', 'Report Cards']
      },
      {
        title: 'BizFlow CRM',
        desc: 'High-speed multi-channel sales pipeline, lead attribution, automated follow-ups and partner visit tracking software.',
        price: '120000',
        features: ['Realtime Lead Pipeline', 'Channel Partner Visits', 'Instant Push Alerts', 'Team Performance Metrics']
      },
      {
        title: 'HospitalCloud 360',
        desc: 'Modern healthcare EHR, outpatient/inpatient billing, pharmacy inventory and doctor appointment scheduling.',
        price: '250000',
        features: ['OPD/IPD Billing', 'Electronic Medical Records', 'Pharmacy Inventory', 'Lab Reports Management']
      }
    ];

    for (const p of seedProducts) {
      const checkRes = await client.query(
        `SELECT id FROM public.crm_records WHERE entity_type = 'product' AND title = $1 LIMIT 1;`,
        [p.title]
      );
      if (checkRes.rows.length === 0) {
        await client.query(
          `INSERT INTO public.crm_records (entity_type, title, description, team, status, extra_data)
           VALUES ('product', $1, $2, 'Both', 'active', $3);`,
          [p.title, p.desc, JSON.stringify({ price: p.price, features: p.features, category: 'Enterprise' })]
        );
        console.log(`Product created: ${p.title}`);
      } else {
        console.log(`Product already exists: ${p.title}`);
      }
    }

    console.log('Database migration & seeding completed flawlessly!');
  } catch (err) {
    console.error('Migration error:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

runMigration();

