#!/usr/bin/env python3
"""
CLI for managing tenants and professionals in the clinic SaaS platform.

Usage:
    python cli.py add-tenant --name "Clinic Name" --evolution-instance "instance_name"
    python cli.py add-professional --clinic "Clinic Name" --name "Dr. Smith"
    python cli.py list-tenants
    python cli.py list-professionals --clinic "Clinic Name"
"""

import argparse
import os
import sys
import uuid

def get_conn():
    """Get database connection using environment variables."""
    try:
        import psycopg2
    except ImportError:
        print("ERROR: psycopg2 not installed. Run: pip install psycopg2-binary", file=sys.stderr)
        sys.exit(1)
    
    return psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", os.getenv("POSTGRES_DB", "n8n_clinic_db")),
        user=os.getenv("PGUSER", os.getenv("POSTGRES_USER", "n8n_clinic")),
        password=os.getenv("PGPASSWORD", os.getenv("POSTGRES_PASSWORD", "")),
        connect_timeout=5,
    )


def cmd_add_tenant(args):
    """Create a new tenant (clinic)."""
    name = args.name
    evolution_instance = args.evolution_instance or name.lower().replace(" ", "_").replace("-", "_") + "_instance"
    slug = args.slug or name.lower().replace(" ", "-").replace(".", "")[:50]
    
    with get_conn() as conn:
        with conn.cursor() as cur:
            # Check for duplicates
            cur.execute(
                "SELECT tenant_id FROM tenant_config WHERE tenant_name = %s OR evolution_instance_name = %s OR tenant_slug = %s",
                (name, evolution_instance, slug),
            )
            if cur.fetchone():
                print("ERROR: Tenant with that name, instance or slug already exists.", file=sys.stderr)
                sys.exit(1)
            
            tenant_id = str(uuid.uuid4())
            cur.execute(
                """
                INSERT INTO tenant_config (
                    tenant_id, tenant_name, tenant_slug, evolution_instance_name,
                    clinic_name, clinic_type, timezone,
                    system_prompt_patient, system_prompt_internal, system_prompt_confirmation,
                    whatsapp_number
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s
                )
                """,
                (
                    tenant_id,
                    name,
                    slug,
                    evolution_instance,
                    name,
                    args.clinic_type or "mixed",
                    args.timezone or "America/Sao_Paulo",
                    f"Você é a atendente virtual da {name}. Responda de forma objetiva e profissional.",
                    f"Você é o assistente interno da {name} para a equipe.",
                    f"Você envia lembretes de consulta da {name}.",
                    args.whatsapp or None,
                ),
            )
            
            # Store API key if provided
            if args.apikey:
                cur.execute(
                    "INSERT INTO tenant_secrets (tenant_id, secret_key, secret_value_encrypted, secret_type) VALUES (%s, %s, %s, 'api_key')",
                    (tenant_id, "evolution_api_key", args.apikey),
                )
            
            conn.commit()
    
    print(f"✅ Created tenant: {name}")
    print(f"   Slug: {slug}")
    print(f"   Evolution Instance: {evolution_instance}")
    print(f"   Tenant ID: {tenant_id}")


def cmd_add_professional(args):
    """Add a professional to a clinic."""
    clinic = args.clinic
    professional_name = args.name
    
    with get_conn() as conn:
        with conn.cursor() as cur:
            # Find the clinic
            cur.execute(
                """SELECT tenant_id, clinic_name FROM tenant_config 
                   WHERE is_active AND (tenant_name = %s OR tenant_slug = %s OR evolution_instance_name = %s) 
                   LIMIT 1""",
                (clinic, clinic, clinic),
            )
            row = cur.fetchone()
            if not row:
                print(f"ERROR: Clinic '{clinic}' not found.", file=sys.stderr)
                sys.exit(1)
            
            tenant_id, clinic_name = row
            slug = args.slug or professional_name.lower().replace(" ", "-").replace(".", "")[:100]
            
            # Check for duplicate
            cur.execute(
                "SELECT professional_id FROM professionals WHERE tenant_id = %s AND professional_slug = %s",
                (tenant_id, slug),
            )
            if cur.fetchone():
                print(f"ERROR: Professional with slug '{slug}' already exists in this clinic.", file=sys.stderr)
                sys.exit(1)
            
            professional_id = str(uuid.uuid4())
            cur.execute(
                """
                INSERT INTO professionals (
                    professional_id, tenant_id, professional_name, professional_slug, 
                    specialty, google_calendar_id, slot_interval_minutes
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    professional_id,
                    tenant_id,
                    professional_name,
                    slug,
                    args.specialty or "Geral",
                    args.calendar_id or None,
                    args.slot_minutes or 30,
                ),
            )
            conn.commit()
    
    print(f"✅ Created professional: {professional_name}")
    print(f"   Clinic: {clinic_name}")
    print(f"   Slug: {slug}")
    print(f"   Specialty: {args.specialty or 'Geral'}")
    print(f"   Professional ID: {professional_id}")


def cmd_list_tenants(args):
    """List all tenants."""
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT tenant_name, tenant_slug, evolution_instance_name, 
                          clinic_type, is_active, subscription_tier, created_at
                   FROM tenant_config ORDER BY created_at DESC"""
            )
            rows = cur.fetchall()
    
    if not rows:
        print("No tenants found.")
        return
    
    print(f"{'Name':<30} {'Slug':<20} {'Instance':<25} {'Type':<10} {'Active':<8} {'Tier':<12}")
    print("─" * 115)
    for row in rows:
        name, slug, instance, ctype, active, tier, created = row
        status = "✅" if active else "❌"
        print(f"{name:<30} {slug:<20} {instance:<25} {ctype:<10} {status:<8} {tier:<12}")


def cmd_list_professionals(args):
    """List professionals for a clinic."""
    clinic = args.clinic
    
    with get_conn() as conn:
        with conn.cursor() as cur:
            # Find the clinic
            cur.execute(
                """SELECT tenant_id, clinic_name FROM tenant_config 
                   WHERE tenant_name = %s OR tenant_slug = %s OR evolution_instance_name = %s 
                   LIMIT 1""",
                (clinic, clinic, clinic),
            )
            row = cur.fetchone()
            if not row:
                print(f"ERROR: Clinic '{clinic}' not found.", file=sys.stderr)
                sys.exit(1)
            
            tenant_id, clinic_name = row
            
            cur.execute(
                """SELECT professional_name, professional_slug, specialty, 
                          google_calendar_id, is_active, slot_interval_minutes
                   FROM professionals 
                   WHERE tenant_id = %s
                   ORDER BY display_order, professional_name""",
                (tenant_id,)
            )
            rows = cur.fetchall()
    
    print(f"\n📋 Professionals at {clinic_name}\n")
    if not rows:
        print("No professionals found.")
        return
    
    print(f"{'Name':<25} {'Slug':<20} {'Specialty':<25} {'Calendar':<10} {'Active':<8} {'Slot':<6}")
    print("─" * 100)
    for row in rows:
        name, slug, specialty, calendar, active, slot = row
        status = "✅" if active else "❌"
        cal_status = "✅" if calendar else "❌"
        print(f"{name:<25} {slug:<20} {specialty:<25} {cal_status:<10} {status:<8} {slot:<6}")


def main():
    parser = argparse.ArgumentParser(
        prog="clinic-cli",
        description="CLI for managing clinic SaaS tenants and professionals"
    )
    sub = parser.add_subparsers(dest="command", required=True)
    
    # add-tenant
    p_tenant = sub.add_parser("add-tenant", help="Create a new tenant (clinic)")
    p_tenant.add_argument("--name", required=True, help="Tenant display name")
    p_tenant.add_argument("--evolution-instance", help="Evolution API instance name (default: derived from name)")
    p_tenant.add_argument("--slug", help="URL-safe slug (default: derived from name)")
    p_tenant.add_argument("--whatsapp", help="WhatsApp number")
    p_tenant.add_argument("--apikey", help="API key (stored in tenant_secrets)")
    p_tenant.add_argument("--timezone", default="America/Sao_Paulo")
    p_tenant.add_argument("--clinic-type", choices=["medical", "aesthetic", "mixed", "dental", "other"], default="mixed")
    p_tenant.set_defaults(func=cmd_add_tenant)
    
    # add-professional
    p_pro = sub.add_parser("add-professional", help="Add a professional to a clinic")
    p_pro.add_argument("--clinic", required=True, help="Clinic name, slug, or evolution instance name")
    p_pro.add_argument("--name", required=True, help="Professional full name")
    p_pro.add_argument("--slug", help="URL-safe slug (default: derived from name)")
    p_pro.add_argument("--specialty", default="Geral")
    p_pro.add_argument("--calendar-id", help="Google Calendar ID")
    p_pro.add_argument("--slot-minutes", type=int, default=30)
    p_pro.set_defaults(func=cmd_add_professional)
    
    # list-tenants
    p_list = sub.add_parser("list-tenants", help="List all tenants")
    p_list.set_defaults(func=cmd_list_tenants)
    
    # list-professionals
    p_list_pro = sub.add_parser("list-professionals", help="List professionals for a clinic")
    p_list_pro.add_argument("--clinic", required=True, help="Clinic name, slug, or evolution instance name")
    p_list_pro.set_defaults(func=cmd_list_professionals)
    
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()