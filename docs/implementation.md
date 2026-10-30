# Implementation Guide — Selective ERP Sent-Mail Archiving with Mailcow

> **Sanitized portfolio documentation.** The addresses, domains, host identifiers, message samples, and subject values below are illustrative. They are **not** production exports or a drop-in configuration. No real employee or recipient data is included.

## 1. Objective and environment

Two business applications (an ERP warehouse workflow and an HRM workflow) submitted messages through a company-managed Mailcow SMTP service. Recipients received the emails and their PDF attachments, but the sending mailboxes did not show corresponding messages in **Sent** in either Outlook or SOGo.

The requirement was to preserve *only application-generated* outgoing messages in dedicated Sent subfolders without duplicating routine Outlook messages. The implementation used the Mailcow administrative interface; it did not require direct shell access to the mail server or changes to the ERP application.

**Components:** Mailcow, Postfix (SMTP), Dovecot/Sieve, SOGo, Outlook, sender BCC maps, tagged/plus addresses.

## 2. Root-cause investigation

SMTP delivery and saving a message in Sent are separate operations:

1. The application submits the message over SMTP; Postfix routes it to the recipient.
2. A conventional mail client also saves a copy to a Sent folder, commonly through IMAP APPEND.

The applications completed the first operation but did not save the second copy. Mailcow logs showed successful authenticated submission and delivery; the absence of the item from both Outlook and SOGo indicated that this was not merely an Outlook synchronization issue.

A **sanitized schematic** of the evidence (not an actual log excerpt):

```text
sasl_username=warehouse@example.com
from=<warehouse@example.com>
to=<recipient@example.net>
status=sent
```

> `status=sent` supports successful delivery at the logged transport stage; it does not prove that the sending mailbox has a Sent copy.

## 3. Solution design

The implementation combined three server-side features:

- **Sender BCC map:** produce a separate archive copy for outgoing messages submitted by the selected sender.
- **Plus addressing:** direct that copy to a tagged variant of the same mailbox, such as `warehouse+archive@example.com`; no additional mailbox is created.
- **Dovecot Sieve prefilter:** inspect the tagged archive copy and file matching application messages into a designated Sent subfolder; discard nonmatching **archive copies**.

```text
ERP / HRM ----SMTP----> Mailcow / Postfix ----> Original recipient
                           |
                           +-- Sender BCC --> tagged address
                                                 |
                                            Sieve prefilter
                                            /           \
                                     matches           other
                                       |                |
                                Sent subfolder     discard BCC copy
```

The discard action was designed to apply only to the additional BCC copy, not the original message delivered to the actual recipient. **That separation depends on correctly scoped sender BCC rules and a prefilter that checks the tagged destination.**

### 3.1 Tagged-mail behavior

For each relevant mailbox, the tagged-mail handling setting was configured to **Do nothing** so Mailcow would not automatically create extra Inbox subfolders for tagged addresses. The prefilter determined the destination instead. The target subfolder was created in SOGo before enabling the filter, and its exact mailbox path and capitalization were checked.

## 4. HRM use case — message-header matching

**Goal:** archive HRM-generated emails in a dedicated folder while routine Outlook messages from the same mailbox continue to appear only in the normal Sent folder.

### 4.1 Sender BCC map (illustrative values)

In Mailcow Admin, navigate to **E-Mail → Configuration → Address rewriting → BCC maps**, then configure a sender map:

```text
Local destination: payroll@example.com
BCC type:          Sender map
BCC destination:   payroll+hrm@example.com
Active:            Yes
```

Create the folder `Sent/Pylon HRM` in the mailbox.

### 4.2 Sieve prefilter (illustrative example)

The actual investigation observed a difference in the generated `Message-ID` headers of HRM and Outlook mail. The following placeholder `@APPHOST` expresses the *matching strategy* but **must not be treated as a validated production fingerprint**.

```sieve
require ["fileinto", "envelope", "subaddress"];

if envelope :detail :is "to" "hrm" {
    if header :contains "Message-ID" "@APPHOST" {
        fileinto "Sent/Pylon HRM";
    } else {
        discard;
    }
    stop;
}
```

Add the prefilter under **E-Mail → Configuration → Filters**, selecting the appropriate mailbox and **Prefilter** type; validate before saving.

**Observed outcome:** an HRM-generated test message was received by the intended recipient and archived in `Sent/Pylon HRM`. A normal Outlook test message was delivered and retained in standard Sent without appearing in the HRM archive.

**Limitation:** a workstation-dependent `Message-ID` pattern can change when the application moves or its message generation changes. The result may be a missing archive copy rather than failed recipient delivery. Reinspect the new headers and update the matcher as needed; prefer a stable application identifier or dedicated submission identity when available.

## 5. Warehouse ERP use case — subject matching

**Goal:** archive ERP-generated shipping-document emails while excluding unrelated messages from a shared mailbox. A workstation identifier was deliberately avoided because multiple users and PCs sent from this mailbox.

### 5.1 Sender BCC map (illustrative values)

```text
Local destination: warehouse@example.com
BCC type:          Sender map
BCC destination:   warehouse+dap@example.com
Active:            Yes
```

Create a dedicated folder, represented here as `Sent/Shipping Documents`.

### 5.2 Sieve prefilter (illustrative example)

The actual implementation matched several observed *Greek-language* subject patterns. The following English strings are **translated examples for documentation**, not the literal production subjects:

```sieve
require ["fileinto", "envelope", "subaddress"];

if envelope :detail :is "to" "dap" {
    if anyof (
        header :is "Subject" "Shipping Document",
        header :contains "Subject" "DAP",
        header :contains "Subject" "WAREHOUSE DOCUMENT"
    ) {
        fileinto "Sent/Shipping Documents";
    } else {
        discard;
    }
    stop;
}
```

Create this as a mailbox **Prefilter** in Mailcow, validate the syntax, and verify that the folder name is correct.

**Observed outcome:** tests with application-produced shipping documents created archive copies in the dedicated folder. Normal Outlook mail did not enter that folder.

**Limitation:** subject-based matching is incomplete when subjects can be freely edited. A new or unrelated subject pattern may cause the extra archive copy to be discarded. Standardizing an application-specific prefix would make this more maintainable.

## 6. Testing methodology

Both positive and negative cases were exercised for the workflows.

| Test | Expected verification |
| --- | --- |
| ERP/HRM-generated message | Intended recipient receives the email and attachment; matching archive copy appears in dedicated folder |
| Ordinary Outlook message from same account | Intended recipient receives email; Outlook saves normal Sent item; no application archive duplicate |
| Nonmatching tagged BCC copy | Extra archive copy is discarded by Sieve, without changing normal recipient delivery |

After changes, inspect the *actual* archive folder, the Inbox for unintended tagged copies, and available Mailcow logs. These documented tests validate the observed behavior at the time of implementation; they do not guarantee future matching if application headers or subjects change.

## 7. Troubleshooting

| Symptom | Checks |
| --- | --- |
| Recipient receives nothing | SMTP submission/authentication and Postfix delivery logs; treat as delivery issue |
| Recipient receives message, archive empty | BCC map active; tagged address; tagged-mail setting; prefilter activation; matcher; exact folder path |
| Archive copy lands in Inbox | BCC was generated but Sieve routing or folder name may be wrong |
| Normal Outlook messages appear in archive | Matcher is too broad; compare headers/subjects and narrow it |
| Archive suddenly stops after moving HRM | Check whether the `Message-ID` fingerprint changed |
| Some shipping messages missing | Check newly introduced or edited subject patterns |

### Safe rollback

To stop generating archive copies, disable the relevant **sender BCC map first**. If the prefilter alone is disabled while the BCC map remains enabled, tagged copies may start accumulating in Inbox. Revalidate the filters before re-enabling the map.

## 8. Responsibility and operational scope

The solution was configured and tested through Mailcow's administrative UI. It relied on existing application SMTP submission and Mailcow capabilities, without modifying the ERP software itself. The documented separation between recipient delivery and optional archive-copy routing is an important design property, but operations still require periodic checks of the matching patterns and archive folders.

## 9. Publication and reuse notes

- The configuration samples use **fictional addresses** and **illustrative filters**; they are not exact production exports.
- No real domains, personnel, recipient addresses, Message-IDs, workstation names, customer document numbers, authentication values, or production log lines are included.
- Folder names and matching logic must be adapted and tested against the target Mailcow/Dovecot environment.
- Do not enable `discard` rules in production without verifying that they apply exclusively to the intended tagged archive copy.

For the concise overview, return to [README](../README.md).
