# Zpro FREE System

To add domains to the system, simply configure the `ADMIN_DOMAIN` variable in your `.env` file:

```env
ADMIN_DOMAIN=zpro.io,yourdomain.com,anotherdomain.net
---

यह मेरे ब्राज़ीलियाई दोस्तों की मदद के लिए साझा किया गया है — ज्ञान बाँटना गलत नहीं है।
Reset the repository; don't fork it to avoid being tracked.

I analyzed the code and found that it sends a significant amount of data externally 
through multiple webhooks. This includes sensitive information such as contact data 
and tenant details. In addition, it transmits data to various external services, 
including Discord, Telegram, and even email addresses associated with third parties 
(such as a pharmacy).

The version we provide has been completely cleaned of this behavior — it does not 
perform any unauthorized external data transmission.

As far as I’m aware, Brazil has strict data protection regulations under the Lei 
Geral de Proteção de Dados (LGPD). The way this system handles data appears to be 
fully non-compliant with those regulations, which raises serious concerns regarding 
privacy, security, and legal exposure.

## License

This project is licensed under the MIT License.
