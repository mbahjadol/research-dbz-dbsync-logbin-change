import pyodbc
import random
import string
import os

DB_SERVER = os.getenv("DB_SERVER", "source-db")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_USER = os.getenv("DB_USER", "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "Password!")
DB_NAME = os.getenv("DB_NAME", "inventory")

CONN_STR = (
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={DB_SERVER},{DB_PORT};DATABASE={DB_NAME};"
    f"UID={DB_USER};PWD={DB_PASSWORD}"
)

def get_conn():
    return pyodbc.connect(CONN_STR)

def random_string(n=10):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=n))

def insert_random_data():
    name = random_string()
    conn = get_conn()
    cursor = conn.cursor()
    info_value = f'#{name} :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex.'
    cursor.execute("INSERT INTO insert_lag(info) VALUES (?)", 
                   (info_value))
    conn.commit()
    cursor.close()
    conn.close()
    return {"status": "inserted", "name": name}

def update_random_data():
    name = random_string()
    random_id = random.randint(1, 10000)    
    conn = get_conn()
    cursor = conn.cursor()
    info_value = f'#{name} :Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex.'
    cursor.execute("UPDATE update_lag SET info = ? WHERE id = ?", 
                   (info_value, random_id))
    affected = cursor.rowcount
    conn.commit()
    cursor.close()
    conn.close()
    return {"status": "updated", "id": random_id, "name": name, "affected": affected}
