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

---

## 2. Arquitectura de la Solución

La solución se despliega de forma distribuida para garantizar que no exista un punto único de fallo (SPOF).

* **StatefulSet:** Garantiza identidades DNS fijas (`validator-0`, `validator-1`, etc.) esenciales para el descubrimiento P2P.
* **Anti-Affinity:** Reglas "soft" que obligan a Kubernetes a colocar cada nodo en un servidor físico y zona de disponibilidad diferente.
* **Headless Service:** Permite el descubrimiento DNS entre nodos incluso antes de que los pods reporten estado "Ready" (`publishNotReadyAddresses: true`).

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

Este documento es parte integral del sistema de gobernanza de Human Is Kind. Para soporte técnico, contactar al equipo de infraestructura HIK.