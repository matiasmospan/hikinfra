# HIK Besu Blockchain Infrastructure (Cloud-Native)

Este componente constituye la capa de inmutabilidad del ecosistema **Human Is Kind (HIK)**. Utiliza Hyperledger Besu para gestionar el registro de auditoría, las firmas de integridad y el despliegue de contratos inteligentes en una red permisionada de alta disponibilidad.

---

## 1. Resumen de Funcionalidades

La arquitectura está diseñada para cumplir con estándares de misión crítica en entornos corporativos:

* **Consenso QBFT (Quorum Byzantine Fault Tolerance):** Finalidad inmediata de las transacciones, ideal para redes privadas donde la velocidad y la certeza son ley.
* **Gestión Dinámica de Identidad:** Automatización completa de la generación de llaves (Enode, Direcciones de Validador) mediante Jobs de Kubernetes y RBAC estricto.
* **Aislamiento de Red (Zero-Trust):** Micro-segmentación mediante Network Policies que bloquean todo tráfico excepto el P2P necesario y las llamadas RPC autorizadas.
* **Despliegue de Contratos "Post-Install":** Automatización del despliegue del Registry de HIK una vez que la red alcanza el quórum.
* **Persistencia Segura:** Uso de almacenamiento premium con permisos de usuario no raíz y perfiles de seguridad (Seccomp/RuntimeDefault).
* **Hardening de Contenedores**: Ejecución con usuarios no-root, capacidades de kernel restringidas y perfiles Seccomp.

---

## 2. Arquitectura de la Solución

La solución se despliega de forma distribuida para garantizar que no exista un punto único de fallo (SPOF).

* **StatefulSet:** Garantiza identidades DNS fijas (`validator-0`, `validator-1`, etc.) esenciales para el descubrimiento P2P.
* **Anti-Affinity:** Reglas "soft" que obligan a Kubernetes a colocar cada nodo en un servidor físico y zona de disponibilidad diferente.
* **Headless Service:** Permite el descubrimiento DNS entre nodos incluso antes de que los pods reporten estado "Ready" (`publishNotReadyAddresses: true`).

graph TD;
    subgraph "Aprovisionamiento (Hooks)"
        RBAC[RBAC: Roles/SA] -- Permite --> Keygen[Job: Keygen]
        Keygen -- Genera y Guarda --> Secret[Secret: Identities/Genesis]
    end

    subgraph "Capa de Consenso (Inmutable)"
        Secret -- Inyecta vía Init --> Val0[Validator Pod 0]
        Secret -- Inyecta vía Init --> Val1[Validator Pod 1]
        Secret -- Inyecta vía Init --> Val2[Validator Pod 2]
        Val0 <-->|P2P Port 30303| Val1
        Val1 <-->|P2P Port 30303| Val2
        Val2 <-->|P2P Port 30303| Val0
    end

    subgraph "Capa de Acceso y Aplicación"
        Val0 & Val1 & Val2 -->|Sincronía| RPC[Nodo RPC / Bootnode]
        RPC -- Expone JSON-RPC 8545 --> DApp[HIK Explorer / Middleware]
        NetPol[Network Policies] -.->|Filtra Tráfico| LayerAcceso[Capa Aplicativa]
    end

    style Secret fill:#f9f,stroke:#333,stroke-width:2px
    style RBAC fill:#fff4dd,stroke:#d4a017,stroke-width:2px
    style NetPol fill:#ffcccb,stroke:#a30000,stroke-width:2px

### Detalle de Componentes y su Finalidad

|Componente|Recurso K8s|Finalidad Técnica y Seguridad|
|--|--|--|
|RBAC Manager|ServiceAccount, Role|Define las facultades de los Jobs. Posee permisos de create/patch sobre Secrets y ConfigMaps. Sin permisos de borrado global.|
|Keygen Engine|Job (pre-install)|Script en Node.js/Alpine que genera la topología de red. Se auto-elimina al finalizar para no dejar huellas de logs sensibles.|
|Validators|StatefulSet|El "Core" de la red. Ejecuta Besu con runAsUser: 1000. Utiliza podAntiAffinity para garantizar dispersión geográfica (Multi-AZ).|
|RPC Gateway|Deployment|Punto de entrada para consultas. Posee una NetworkPolicy específica que solo permite tráfico desde el Middleware autorizado.|
Identities|Secret|Contiene los archivos key (llave privada del nodo) y el static-nodes.json. Protegido por cifrado en reposo del clúster (KMS).|
|Network Shield|NetworkPolicy|Implementa el aislamiento. Cierra todos los puertos excepto el 30303 (P2P) entre validadores y el 8545 (RPC) para la aplicación.|
|Discovery Service|Service (Headless)|Permite que los nodos se encuentren por nombre DNS (validator-0.besu-internal) incluso antes de estar en estado "Ready".|

### Archivos Críticos del Despliegue
* `genesis.json`: Define la "Constitución" de la blockchain (ChainID, algoritmo QBFT, cuentas pre-fondeadas).

* `static-nodes.json`: El mapa de confianza inicial. Sin este archivo, los nodos no saben a quién llamar para armar la red.

* `security-context.yaml`: Define que el sistema de archivos sea de solo lectura (readOnlyRootFilesystem: true) excepto en la carpeta de datos.

---

## 3. Despliegue y Configuración

### Requisitos Previos
* Cluster de Kubernetes (v1.24+) con soporte para Network Policies.
* Helm v3+.
* StorageClass configurado (Default o específico).

### Procedimiento de Instalación
```bash
# 1. Clonar el repositorio del chart
git clone <url-repositorio-hik>

# 2. Instalar el chart (Helm se encargará de los hooks de RBAC y Keygen)
helm install hik-besu ./hik-besu-chart -n besu --create-namespace
```

### Variables Principales (values.yaml)
El chart es agnóstico al proveedor de nube. Si se dejan los valores por defecto, usará los recursos estándar del clúster.

|Variable|Descripción|Valor Recomendado|
|---|---|---|
|nodes.image|Imagen oficial de Besu optimizada.|hyperledger/besu:latest|
|nodes.replicas|Cantidad de nodos validadores (mínimo 3 para QBFT).|3|
|storage.className|Clase de almacenamiento (vacío para default).|"" o "premium-rwo"|
|storage.size|Tamaño del disco por nodo validador.|50Gi|
|resources.limits.memory|Límite de RAM por nodo (60% para JVM).|4Gi|
|network.rpcAccessLabel|Label requerido para que otros pods hablen con la red.|access-rpc: "true"|

---

## 4. Parámetros de Performance y Disponibilidad

Basado en las pruebas de carga y la configuración de infraestructura actual en GKE:

### Disponibilidad (SLA Estimado)
* **Nivel de Servicio:** 99.99% (Cuatro Nueves).
* **Resiliencia:** Tolerancia a fallos a nivel de Pod, Nodo físico y Zona de Disponibilidad.
* **Recuperación:** Auto-sanación mediante Liveness y Readiness probes. Los nodos sincronizan automáticamente al reincorporarse.

### Rendimiento (Benchmarks)
* **Transacciones por Segundo (TPS):** 300 - 800 TPS (dependiendo de la complejidad de la lógica del contrato y el IOPS del disco).
* **Tiempo de Bloque:** 2 segundos (Configurable en el génesis).
* **Finalidad:** Inmediata. Una vez que la transacción se incluye en un bloque, es irreversible gracias al consenso QBFT.
* **Latencia RPC:** < 50ms dentro del mismo clúster de Kubernetes.

---

Este documento es parte integral del sistema de gobernanza de Human Is Kind. Para soporte técnico, contactar al equipo de infraestructura HIK.