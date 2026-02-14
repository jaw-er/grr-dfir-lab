# GRR DFIR Lab 🔎

![Python](https://img.shields.io/badge/Bash-blue)
![License MIT](https://img.shields.io/badge/License-MIT-green)

Déploiement automatisé d’un environnement GRR 3.2.4.5 (pre-Fleetspeak) pour laboratoires DFIR (Digital Forensics & Incident Response).

#### 👤 Auteur : Jawad Errougui

**📧 Email :** j.errougui@gmail.com

**🛠️ Langage :** Bash

**📜 Licence :** MIT

## 📌 Présentation du Projet

Ce projet fournit deux scripts permettant de déployer rapidement un environnement complet GRR :

✅ Installation automatique du serveur GRR 3.2.4.5 via Docker

✅ Déploiement automatisé des agents Linux GRR 3.2.4.5 sur des machines clientes

L’objectif est de simplifier la mise en place d’un lab DFIR pour :

- Threat Hunting
- Analyse forensique
- Incident response
- Tests SOC
- Environnements pédagogiques

## 🏗️ Architecture
                ┌──────────────────────────┐
                │     GRR Server (Docker)  │
                │  Ubuntu + Docker Engine  │
                └──────────────┬───────────┘
                               │ SSH
                               ▼
                ┌──────────────────────────┐
                │      Linux Clients       │
                │   Ubuntu 20/22/24 LTS    │
                └──────────────────────────┘

## 🚀 Installation du Serveur GRR
📂 Script
grr_auto_installer.sh

#### ▶️ Installation

```bash
git clone https://github.com/jaw-er/grr-dfir-lab.git
cd grr-dfir-lab
sudo ./grr_auto_installer.sh
```
#### 🔍 Ce que fait le script serveur

1- Vérifie l’exécution en root

2- Met à jour la liste des paquets (apt update)

3- Installe Docker & Docker Compose

4- Crée le répertoire /opt/grr-lab

5- Génère automatiquement un docker-compose.yml

6- Télécharge et démarre GRR 3.2.4.5

7- Affiche l’IP détectée et l’URL d’accès :

```bash
http://<SERVER_IP>:8000
```

## 🖥️ Déploiement des Agents Linux

📂 Script
deploy_linux_grr_agents.sh

#### 📌 Objectif
Permet de déployer automatiquement l’agent GRR Linux depuis le serveur vers des machines clientes distantes.

#### ⚠️ Prérequis
Avant d’exécuter le script :

1️⃣ Le serveur GRR doit être fonctionnel.

2️⃣ SSH doit être activé sur les clients Linux.

Sur chaque machine cliente :
```bash
sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo systemctl start ssh
```
Vérification :
```bash
sudo systemctl status ssh
```
Le port 22 doit être accessible depuis le serveur GRR.

#### ▶️ Utilisation

Depuis le serveur GRR :
```bash
cd grr-dfir-lab
sudo ./deploy_linux_grr_agents.sh <IP_CLIENT> <USERNAME_CLIENT>
```
Exemple :
```bash
sudo ./deploy_linux_grr_agents.sh 192.168.1.50 analyst
```
Le script demandera ensuite le mot de passe SSH du client.

#### 🔍 Ce que fait le script agent

1- Vérifie les privilèges root

2- Vérifie / installe sshpass

3- Teste la connectivité réseau

4- Affiche les informations système du client

5- Vérifie si GRR est déjà installé

6- Récupère automatiquement le package agent depuis Docker

7- Copie l’agent vers le client

8- Installe et active le service GRR

À la fin apparaît :
```bash
[+] GRR Agent 3.2.4.5 prêt sur <IP_CLIENT>
```
L’agent apparaîtra ensuite dans :
```bash
http://<SERVER_IP>:8000
```
## 🧪 Environnements Testés
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## 🔐 Sécurité & Usage
Ce projet est destiné à :
- Environnements de test
- Labs pédagogiques
- Simulations SOC

⚠️ Non recommandé tel quel pour un environnement de production sans durcissement supplémentaire.

## 📜 Licence

MIT License
Copyright (c) 2025 Jawad Errougui
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction...

The original script banner displaying the author's name must be preserved.

## 📬 Contact
Pour toute question, suggestion ou amélioration :

📧 j.errougui@gmail.com
