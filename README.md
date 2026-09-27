# Stack Microservicios (Go + Flutter + gRPC + Cassandra)

Este proyecto es un entorno full-stack desacoplado que utiliza **Go** para el backend, **Flutter** para el frontend, comunicación en tiempo real mediante **gRPC / gRPC-Web** y **Apache Cassandra** como base de datos persistente.

---

## 🛠️ Requisitos Previos

Antes de comenzar, asegúrate de tener instalado en tu sistema:

* **Git**
* **Docker** y **Docker Compose**
* **Go** (v1.20+)
* **Flutter SDK** (v3.0+)
* **Protocol Buffers Compiler (`protoc`)**:
  * **Windows:** Descargar desde [GitHub Releases de Protobuf](https://github.com/protocolbuffers/protobuf/releases), extraer y agregar el directorio `bin` a tu `PATH`.
  * **Linux (Ubuntu/Debian):** `sudo apt update && sudo apt install -y protobuf-compiler`

---

## 🚀 Guía de Configuración e Instalación

### 1. Clonar el repositorio
```bash
git clone [https://github.com/ARQUImediaa/StackMicroservicios.git](https://github.com/ARQUImediaa/StackMicroservicios.git)
cd StackMicroservicios
```

---

### 2. Iniciar la Base de Datos (Cassandra)
Levanta el contenedor de Cassandra en segundo plano:

```bash
docker compose up -d
```
*(Nota: Cassandra puede tardar entre 30 y 60 segundos en iniciar completamente).*

---

### 3. Generar Código gRPC (Solo si modificas `proto/service.proto`)

#### Para el Backend (Go):
Instalar plugins de Go para `protoc`:
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```
Compilar contrato Proto:
```bash
# Windows / Linux (Desde la raíz del proyecto)
protoc --proto_path=proto --go_out=backend/pb --go_opt=paths=source_relative --go-grpc_out=backend/pb --go-grpc_opt=paths=source_relative proto/service.proto
```

#### Para el Frontend (Flutter):
Activar plugin de Dart:
```bash
dart pub global activate protoc_plugin
```
Compilar contrato Proto:
* **Linux / macOS:**
  ```bash
  protoc --proto_path=proto --dart_out=grpc:frontend/lib/pb proto/service.proto
  ```
* **Windows (PowerShell):**
  ```powershell
  protoc --plugin=protoc-gen-dart=$env:LOCALAPPDATA\Pub\Cache\bin\protoc-gen-dart.bat --proto_path=proto --dart_out=grpc:frontend/lib/pb proto/service.proto
  ```

---

### 4. Ejecutar el Backend (Go)

Abre una terminal en la carpeta del backend:

```bash
cd backend
go mod tidy
go run main.go
```
El servidor gRPC y gRPC-Web estará escuchando en el puerto **`:50051`**.

---

### 5. Ejecutar el Frontend (Flutter)

Abre una **segunda terminal** en la carpeta del frontend:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```
*(También puedes ejecutar `flutter run -d windows` o `flutter run -d linux` según tu sistema operativo).*

---

## 📂 Estructura del Proyecto

```text
├── backend/            # Servidor Go y lógica gRPC-Web / Cassandra
│   ├── pb/             # Código Go generado por gRPC
│   ├── main.go         # Punto de entrada del servidor
│   └── go.mod          # Módulos de Go
├── frontend/           # Aplicación Flutter Multiplataforma
│   ├── lib/
│   │   ├── pb/         # Código Dart/gRPC generado
│   │   └── main.dart   # Interfaz de usuario e integración gRPC
│   └── pubspec.yaml    # Dependencias de Flutter
├── proto/              # Contratos y definiciones gRPC
│   └── service.proto
└── docker-compose.yml  # Configuración de infraestructura Cassandra
```
