import sqlite3
import pandas as pd
import streamlit as st

# --- DATABASE SETUP ---
DB_FILE = "quality_inspection.db"

def init_db():
    """Creates the database tables if they do not exist."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # Parts Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS parts (
            record_no TEXT PRIMARY KEY,
            status TEXT,
            equipment TEXT,
            part_number TEXT
        )
    """)
    
    # Lots Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS lots (
            lot_number TEXT PRIMARY KEY,
            part_number TEXT,
            die_number TEXT,
            FOREIGN KEY (part_number) REFERENCES parts (part_number)
        )
    """)
    
    # Check Sheet Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS check_sheet (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            part_number TEXT,
            lot_number TEXT,
            inspection_date TEXT,
            inspector TEXT,
            val_1 REAL,
            val_2 REAL,
            result TEXT
        )
    """)
    
    # Seed initial demo data if tables are empty
    cursor.execute("SELECT COUNT(*) FROM parts")
    if cursor.fetchone()[0] == 0:
        cursor.executemany("INSERT INTO parts VALUES (?, ?, ?, ?)", [
            ("10053", "Inspecting", "R30", "949046-2960"),
            ("10052", "Inspecting", "R52", "053481-7230"),
            ("10049", "Inspecting", "RS41", "AA949043-2560")
        ])
        cursor.executemany("INSERT INTO lots VALUES (?, ?, ?)", [
            ("LC7900555-00", "949046-2960", "24W317ULU"),
            ("LC7002750-00", "053481-7230", "26B035"),
            ("LC7002493-00", "AA949043-2560", "24S369")
        ])
    
    conn.commit()
    conn.close()

init_db()

# --- APP NAVIGATION & STATE ---
st.set_page_config(page_title="Quality Inspection App", layout="wide")

if "step" not in st.session_state:
    st.session_state.step = 1
if "selected_part" not in st.session_state:
    st.session_state.selected_part = None
if "selected_lot" not in st.session_state:
    st.session_state.selected_lot = None

# --- SCREEN 1: PART SELECTION (品番選択画面) ---
if st.session_state.step == 1:
    st.title("1. Part Selection (品番選択画面)")
    
    conn = sqlite3.connect(DB_FILE)
    df_parts = pd.read_sql_query("SELECT * FROM parts", conn)
    conn.close()
    
    search_query = st.text_input("🔍 Search Part Number (品番):", "")
    if search_query:
        df_parts = df_parts[df_parts["part_number"].str.contains(search_query, case=False)]
        
    st.dataframe(df_parts, use_container_width=True, hide_index=True)
    
    st.divider()
    parts_list = df_parts["part_number"].tolist()
    if parts_list:
        selected_part = st.selectbox("Select Part Number to proceed:", parts_list)
        if st.button("Next: Select Lot ➔", type="primary"):
            st.session_state.selected_part = selected_part
            st.session_state.step = 2
            st.rerun()

# --- SCREEN 2: LOT SELECTION (LOT番号選択画面) ---
elif st.session_state.step == 2:
    st.title(f"2. Lot Selection for Part: {st.session_state.selected_part}")
    
    if st.button("⬅ Back to Part Selection"):
        st.session_state.step = 1
        st.rerun()
        
    conn = sqlite3.connect(DB_FILE)
    df_lots = pd.read_sql_query(
        "SELECT * FROM lots WHERE part_number = ?", 
        conn, 
        params=(st.session_state.selected_part,)
    )
    conn.close()
    
    st.dataframe(df_lots, use_container_width=True, hide_index=True)
    
    st.divider()
    lots_list = df_lots["lot_number"].tolist()
    if lots_list:
        selected_lot = st.selectbox("Select LOT Number:", lots_list)
        if st.button("Next: Open Inspection Sheet ➔", type="primary"):
            st.session_state.selected_lot = selected_lot
            st.session_state.step = 3
            st.rerun()

# --- SCREEN 3: CHECK SHEET (寸法の規格＋チェックシート画面) ---
elif st.session_state.step == 3:
    st.title("3. Quality Inspection & Check Sheet")
    st.caption(f"**Selected Part:** {st.session_state.selected_part} | **Selected Lot:** {st.session_state.selected_lot}")
    
    if st.button("⬅ Back to Lot Selection"):
        st.session_state.step = 2
        st.rerun()
        
    st.divider()
    
    # Specs Header
    st.subheader("📐 Dimensional Specifications (寸法の規格)")
    st.info("Spec A: 10.5mm ± 0.1  |  Spec B: 2.0mm ± 0.05  |  Spec C: 15.0mm MAX")
    
    # Data Entry Form
    st.subheader("📋 New Inspection Entry (チェックシート)")
    with st.form("inspection_form"):
        col1, col2 = st.columns(2)
        with col1:
            inspector = st.text_input("Inspector Name (記入者)")
            val_1 = st.number_input("Measurement 1", value=0.0)
        with col2:
            val_2 = st.number_input("Measurement 2", value=0.0)
            result = st.selectbox("Judgment (判定)", ["OK", "NG"])
            
        submitted = st.form_submit_button("💾 Save Inspection Record", type="primary")
        
        if submitted:
            conn = sqlite3.connect(DB_FILE)
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO check_sheet (part_number, lot_number, inspection_date, inspector, val_1, val_2, result)
                VALUES (?, ?, datetime('now'), ?, ?, ?, ?)
            """, (st.session_state.selected_part, st.session_state.selected_lot, inspector, val_1, val_2, result))
            conn.commit()
            conn.close()
            st.success("Record saved successfully to the database!")
            
    # Display saved records
    st.subheader("📊 Saved Records for this Lot")
    conn = sqlite3.connect(DB_FILE)
    saved_records = pd.read_sql_query(
        "SELECT * FROM check_sheet WHERE lot_number = ?", 
        conn, 
        params=(st.session_state.selected_lot,)
    )
    conn.close()
    st.dataframe(saved_records, use_container_width=True, hide_index=True)
