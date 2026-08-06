from sqlalchemy import create_engine, inspect

# Apna password yahan update karo
DATABASE_URL = "postgresql://facevault_admin:facevault_password@localhost:5432/facevault_db"

engine = create_engine(DATABASE_URL)
inspector = inspect(engine)

print("=" * 60)
print("📋 FACE VAULT - ACTUAL DATABASE COLUMNS")
print("=" * 60)

for table_name in inspector.get_table_names():
    print(f"\n🔹 Table: {table_name}")
    print("-" * 40)
    for column in inspector.get_columns(table_name):
        pk = " 🔑 PRIMARY KEY" if column.get('primary_key') else ""
        nullable = "NULL" if column['nullable'] else "NOT NULL"
        print(f"   • {column['name']:25} | {str(column['type']):20} | {nullable}{pk}")

print("\n" + "=" * 60)