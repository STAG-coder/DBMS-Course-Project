"""
Smart Parking DBMS - Presentation III UI
Requirements:
    pip install mysql-connector-python

1. Run smart_parking_final.sql in MySQL.
2. Edit DB_CONFIG below.
3. Run: python app.py

The UI demonstrates:
- INSERT vehicle
- DELETE vehicle
- SELECT/view vehicles
"""
import tkinter as tk
from tkinter import ttk, messagebox
import mysql.connector

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "YOUR_MYSQL_PASSWORD",
    "database": "smart_parking"
}

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

def load_vehicles():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT vehicle_id, plate_number, vehicle_type, owner_name, phone
            FROM Vehicle
            ORDER BY vehicle_id
        """)
        rows = cur.fetchall()
        for item in tree.get_children():
            tree.delete(item)
        for row in rows:
            tree.insert("", tk.END, values=row)
        cur.close()
        conn.close()
        status_var.set(f"{len(rows)} vehicle record(s) loaded.")
    except Exception as e:
        messagebox.showerror("Database Error", str(e))

def add_vehicle():
    plate = plate_var.get().strip()
    vtype = type_var.get()
    owner = owner_var.get().strip()
    phone = phone_var.get().strip()

    if not plate:
        messagebox.showwarning("Input", "Plate number is required.")
        return

    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO Vehicle (plate_number, vehicle_type, owner_name, phone)
            VALUES (%s, %s, %s, %s)
        """, (plate, vtype, owner, phone))
        conn.commit()
        cur.close()
        conn.close()
        clear_form()
        load_vehicles()
        messagebox.showinfo("Success", "Vehicle inserted successfully.")
    except Exception as e:
        messagebox.showerror("Insert Error", str(e))

def delete_vehicle():
    selected = tree.selection()
    if not selected:
        messagebox.showwarning("Delete", "Select a vehicle record first.")
        return

    vehicle_id = tree.item(selected[0], "values")[0]
    if not messagebox.askyesno("Confirm Delete", f"Delete vehicle ID {vehicle_id}?"):
        return

    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM Vehicle WHERE vehicle_id = %s", (vehicle_id,))
        conn.commit()
        cur.close()
        conn.close()
        load_vehicles()
        messagebox.showinfo("Success", "Vehicle deleted successfully.")
    except Exception as e:
        messagebox.showerror(
            "Delete Error",
            "The vehicle may be referenced by a parking session.\n\n" + str(e)
        )

def clear_form():
    plate_var.set("")
    type_var.set("CAR")
    owner_var.set("")
    phone_var.set("")

root = tk.Tk()
root.title("Smart Parking DBMS — Vehicle Management")
root.geometry("900x600")
root.configure(bg="#f4f6fa")

title = tk.Label(
    root, text="Smart Parking DBMS",
    font=("Arial", 24, "bold"), bg="#18326e", fg="white", pady=12
)
title.pack(fill="x")

form = tk.Frame(root, bg="#f4f6fa", padx=20, pady=15)
form.pack(fill="x")

plate_var = tk.StringVar()
type_var = tk.StringVar(value="CAR")
owner_var = tk.StringVar()
phone_var = tk.StringVar()
status_var = tk.StringVar(value="Ready.")

fields = [
    ("Plate Number", plate_var),
    ("Owner Name", owner_var),
    ("Phone", phone_var)
]
for i, (label, var) in enumerate(fields):
    tk.Label(form, text=label, bg="#f4f6fa").grid(row=0, column=i*2, sticky="w", padx=5)
    tk.Entry(form, textvariable=var, width=22).grid(row=0, column=i*2+1, padx=5)

tk.Label(form, text="Vehicle Type", bg="#f4f6fa").grid(row=1, column=0, sticky="w", padx=5, pady=10)
ttk.Combobox(
    form, textvariable=type_var,
    values=["CAR", "BIKE", "HANDICAP", "EV"],
    state="readonly", width=19
).grid(row=1, column=1, padx=5, pady=10)

buttons = tk.Frame(root, bg="#f4f6fa")
buttons.pack(fill="x", padx=20)

tk.Button(buttons, text="Add Vehicle", command=add_vehicle, width=18).pack(side="left", padx=5)
tk.Button(buttons, text="Delete Selected", command=delete_vehicle, width=18).pack(side="left", padx=5)
tk.Button(buttons, text="View / Refresh", command=load_vehicles, width=18).pack(side="left", padx=5)
tk.Button(buttons, text="Clear", command=clear_form, width=12).pack(side="left", padx=5)

frame = tk.Frame(root, padx=20, pady=20)
frame.pack(fill="both", expand=True)

columns = ("vehicle_id", "plate", "type", "owner", "phone")
tree = ttk.Treeview(frame, columns=columns, show="headings")
headers = {
    "vehicle_id": "Vehicle ID",
    "plate": "Plate Number",
    "type": "Vehicle Type",
    "owner": "Owner Name",
    "phone": "Phone"
}
for col in columns:
    tree.heading(col, text=headers[col])
    tree.column(col, width=150)

tree.pack(side="left", fill="both", expand=True)
scroll = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
scroll.pack(side="right", fill="y")
tree.configure(yscrollcommand=scroll.set)

tk.Label(root, textvariable=status_var, bg="#f4f6fa", anchor="w").pack(fill="x", padx=20, pady=5)

load_vehicles()
root.mainloop()
