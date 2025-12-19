# utils.py

def encode_to_hex(value, sensor_type):
    """
    Convierte un número (float) a hexadecimal:
    - Multiplica por 100 para mantener dos decimales
    - Aplica complemento a 2 solo a valores negativos de temperature/humidity
    - No trunca a 16 bits para power
    """
    int_val = int(round(value * 100))
    if sensor_type in ["temperature", "humidity"] and int_val < 0:
        int_val = (1 << 16) + int_val
    return format(int_val, "x")  # hex sin truncar

def decode_from_hex(hex_str, sensor_type):
    """
    Decodifica hexadecimal a float:
    - Aplica complemento a 2 solo a temperature/humidity
    - Divide entre 100 para obtener valor original
    """
    int_val = int(hex_str, 16)
    if sensor_type in ["temperature", "humidity"] and (int_val & 0x8000):
        int_val -= 0x10000
    return int_val / 100.0