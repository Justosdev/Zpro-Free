Send your donation in BTC — any amount is welcome to help us keep contributing.
bc1q2u0mwzlgel3t99789p0n96msajzffx0nwswpja

🚀 LANÇAMENTO OFICIAL | VERSÃO HOMOLOGADA V4.0.0 - 04/05/2026 - v3.1.5.4.16 - 04/05/2026

Fim da fase Alpha. O ZPRO v4 está oficialmente liberado na versão homologada!

⚡️ Pacote Completo v4.0.0 disponível para atualização

🛑 AVISO IMPORTANTE:  faça um BACKUP COMPLETO antes de aplicar esta versão.

🎉 Resumo das novidades:

⚛️ Novo front end React Next.js - interface mais rápida e moderna
🔗 Integrações nativas com Instagram, Facebook e WhatsApp API oficial - Oauth próprio do Zpro
🤖 Copiloto de I.A - Resumos, sugestões de respostas, análises de sentimento...
📱 Novos canais - Mercado Livre, Woocommerce, OLX, Tiktok, Youtube, Linkedin, Rocket.Chat
📈 Rastreamento de conversões Pixel Meta e Google GA4
🎧 Novos recursos de atendimento
👤 Perfil personalizado de usuários
🔌 Novos Endpoints API
🎨 Personalizações
☁️ Armazenamento externo (Storage AmazonS3, etc)
⚡️ Autoinstalador melhorado
💳 Novos gateways de pagamento (stripe, mercadopago, etc)
🚀 Modo Cluster - Infraestrutura para escala com múltiplos núcleos de processamento
📧 Integração com SMTP para envio e recebimento de email nos tickets
✨ Recursos premium baileys / uazapi - botões, listas, etc

Link Download Alpha 22 - https://transfer.it/t/FVLzqC4nxZ6B


🔥 NOVO HOTFIX DISPONÍVEL | v3.1.5.4.15 - 30/04/2026
Correção cumulativa da versão Homolog atual.
⚡️ Pacote frontNovo 4.0.0.alpha.21 disponível para testes

🛑 AVISO: Faça um BACKUP antes de aplicar esta correção.

🆕  NOVIDADES:

➡️ Exclusivo frontNovo 4.0.0.alpha.21:

- youtube comentarios / videos
- mercadolivre autenticação custom domain
- interação transferência de fila + chatbot
- faturamento waba
- conversão gatilho conversa iniciada
- chatgpt + models (aviso system)
- custom link postman
- navegar até mensagem respondida do histórico
- gmail, youtube, calendar com techprovider
- reply email (mantendo a thread de resposta)
- separadores data no chat privado e suporte chat
- botao testar copilot
- resumo contato persistido no banco
- sentimento de conversa persistido no banco
- botão para testar o copilot (configurações)
- icone notificacoes pwa
- ocultar informações de pagamento para user comum (editar tenant superadmin)
- botao para adicionar midias recebidas a galeria
- diagnostico de conexao em sessoes e configurações (waba, ig e messenger oauth)

Link Download Alpha 21 - https://transfer.it/t/iIVFnb4RhD5L


```md
# Zpro FREE System

To add domains to the system, simply configure the `LICENSE_DOMAINS` variable in your `.env` file:

```env
# Licensed domains — separate by comma, no spaces
LICENSE_DOMAINS=meudominio.com,app.meudominio.com

# Optional — UUID of the license code shown in logs
LICENSE_CODE=12345678901234567890
```

---

यह मेरे ब्राज़ीलियाई दोस्तों की मदद के लिए साझा किया गया है — ज्ञान बाँटना गलत नहीं है.  
Reset the repository; don't fork it to avoid being tracked.

---

## Security Notice Version 11/04/2026

I analyzed the code and found that it sends a significant amount of data externally through multiple webhooks. This includes sensitive information such as contact data and tenant details.

In addition, it transmits data to various external services, including Discord, Telegram, and even third-party email addresses.

The version provided here has been completely cleaned of this behavior — it does not perform any unauthorized external data transmission.

Brazil has strict data protection regulations under the Lei Geral de Proteção de Dados (LGPD). The way this system handles data appears to be non-compliant, which raises serious concerns regarding privacy, security, and legal exposure.

---

## ⚠️ Important

This codebase is **NOT the original version**. It has been modified and cleaned.

---

# Security Report: Malicious Code Analysis (ZPro Backend)

This report details the findings of a security analysis performed on the `backend/dist-desofuscate` directory. Multiple malicious behaviors were identified, including tracking, kill switch mechanisms, and anti-analysis protections.

## Summary of Findings

The analyzed code shows behavior consistent with **backdoor-enabled software with aggressive tracking**. It uses heavy obfuscation and a polymorphic structure (spreading malicious code across thousands of files).

---

## Main Malicious Vectors

### 1. Tracking and Data Exfiltration
- **Files:** `server.js`, `3af5ddcfeb0a5584_zpro.js`, and thousands of files in hex folders.
- **Action:** Sends public IP, `BACKEND_URL`, and `FRONTEND_URL` to external domains:
  - `passaportezdg.com.br`
  - `comunidadezdg.com.br`
- **Impact:** Allows external monitoring of all active instances.

---

### 2. Remote Kill Switch (Logic Bomb)
- **File:** `8bd_zpro/9fa70f763d83b5d2_zpro.js`
- **Function:** `startLicenseHeartbeat`
- **Action:** If license validation fails 6 times (~12h), executes SQL:
  - Disables all users and tenants (`inactive = true`)
- **Impact:** System can be remotely disabled at any time.

---

### 3. Anti-Debugging / Anti-Tampering
- **Files:**
  - `91133afc_zpro/7627f0eb65c761_zpro.js`
  - `150fc86fa30f710d_zpro/8dc25e_zpro.js`
- **Action:**
  - Detects `--inspect`
  - Detects code modification
  - Forces `process.exit(1)`
- **Impact:** Prevents analysis and removal of malicious logic.

---

### 4. Polymorphic Structure
- **Action:**
  - Malicious code spread across 700+ directories
- **Impact:**
  - Manual cleanup becomes impractical

---

## Critical Files

| File | Malicious Function | Description |
|------|--------------------|-------------|
| `server.js` | Loader / Sentinel | Initializes protection worker and exfiltrates tenant data on boot |
| `8bd_zpro/9fa70f763d83b5d2_zpro.js` | **Kill Switch** | Disables all users if license fails |
| `91133afc_zpro/7627f0eb65c761_zpro.js` | Anti-Debugging | Detects debuggers and kills process |
| `150fc86fa30f710d_zpro/8dc25e_zpro.js` | Integrity Checker | Detects file changes and alerts attacker |
| `3ec_zpro/48d245ee40_zpro/ac669f33bbdff979_zpro.js` | Boot Validator | Aggressive validation via TLS sockets |
| `.../_zpro/*.js` | Tracking / Decoy | Thousands of files sending tracking data |

---

## Conclusion and Recommendation

The code is **severely compromised**. This is not just a license check — it is a full remote control mechanism over the client instance.

### Recommendation

1. **Do not use this code in production**
2. Block outbound connections to:
   - `*.passaportezdg.com.br`
   - `*.comunidadezdg.com.br`
3. Use a clean version (open-source or original without modifications)
4. If cleaning is required:
   - Remove all `*_zpro` folders
   - Remove `integrityCheck`
   - Remove `heartbeat`
   - Sanitize `server.js`

---

## License

This project is licensed under the MIT License.
```
