FROM python:3.10-slim

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y gcc && apt-get clean

# Copiar requirements e instalar dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar todo el código de la carpeta app/
COPY app/ .

# Exponer puerto de Flask
EXPOSE 8000

# Ejecutar gateway.py que está dentro de /app
CMD ["python", "gateway.py"]
