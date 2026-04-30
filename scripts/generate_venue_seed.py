import csv
import json
import os

csv_path = '/Users/jeanbosco/Downloads/venues_rows.csv'
sql_path = 'supabase/seed_venues.sql'

def escape_sql(val):
    if val is None or val == '' or val == 'NULL':
        return 'NULL'
    return "'" + str(val).replace("'", "''") + "'"

def to_jsonb(val):
    if not val or val == 'NULL':
        return "'{}'::jsonb"
    try:
        # Try to parse as json to validate
        json.loads(val)
        return escape_sql(val) + "::jsonb"
    except:
        return "'{}'::jsonb"

if not os.path.exists(csv_path):
    print(f"Error: {csv_path} not found")
    exit(1)

with open(csv_path, mode='r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    with open(sql_path, mode='w', encoding='utf-8') as out:
        out.write('-- Seed data for venues\n\n')
        for row in reader:
            # Map CSV columns to DB columns
            venue_type = 'bar'
            currency = 'RWF' if row.get('country') == 'RW' else 'EUR'
            
            cols = [
                'id', 'country_code', 'google_place_id', 'slug', 'name', 'address_line1', 
                'latitude', 'longitude', 'hours_json', 'photos_json', 'website_url', 
                'contact_email', 'revolut_link', 'whatsapp', 'is_active', 'created_at', 
                'updated_at', 'ai_description', 'ai_image_url', 'primary_category', 
                'ai_category_confidence', 'last_ai_update', 'price_level', 'rating', 
                'description', 'city', 'claimed', 'owner_email', 'owner_pin', 
                'owner_phone', 'owner_id', 'tenant_id', 'timezone', 'price_band', 
                'features_json', 'verified_at', 'venue_type', 'currency_code'
            ]
            
            vals = [
                escape_sql(row.get('id')),
                escape_sql(row.get('country')),
                escape_sql(row.get('google_place_id')),
                escape_sql(row.get('slug')),
                escape_sql(row.get('name')),
                escape_sql(row.get('address')),
                row.get('lat') if row.get('lat') else 'NULL',
                row.get('lng') if row.get('lng') else 'NULL',
                to_jsonb(row.get('hours_json')),
                to_jsonb(row.get('photos_json')),
                escape_sql(row.get('website')),
                escape_sql(row.get('contact_email')),
                escape_sql(row.get('revolut_link')),
                escape_sql(row.get('whatsapp')),
                'true' if row.get('is_active') == 'true' else 'false',
                escape_sql(row.get('created_at')),
                escape_sql(row.get('updated_at')),
                escape_sql(row.get('ai_description')),
                escape_sql(row.get('ai_image_url')),
                escape_sql(row.get('primary_category')),
                row.get('ai_category_confidence') if row.get('ai_category_confidence') and row.get('ai_category_confidence') != 'NULL' else 'NULL',
                escape_sql(row.get('last_ai_update')),
                row.get('price_level') if row.get('price_level') and row.get('price_level') != 'NULL' else 'NULL',
                row.get('rating') if row.get('rating') and row.get('rating') != 'NULL' else 'NULL',
                escape_sql(row.get('description')),
                escape_sql(row.get('city')),
                'true' if row.get('claimed') == 'true' else 'false',
                escape_sql(row.get('owner_email')),
                escape_sql(row.get('owner_pin')),
                escape_sql(row.get('owner_phone')),
                escape_sql(row.get('owner_id')),
                escape_sql(row.get('tenant_id')),
                escape_sql(row.get('timezone') or 'Europe/Malta'),
                row.get('price_band') if row.get('price_band') and row.get('price_band') != 'NULL' else 'NULL',
                to_jsonb(row.get('features_json')),
                escape_sql(row.get('verified_at')),
                escape_sql(venue_type),
                escape_sql(currency)
            ]
            
            sql = f"INSERT INTO public.venues ({', '.join(cols)}) VALUES ({', '.join(vals)}) ON CONFLICT (id) DO NOTHING;\n"
            out.write(sql)
print(f"Generated {sql_path}")
