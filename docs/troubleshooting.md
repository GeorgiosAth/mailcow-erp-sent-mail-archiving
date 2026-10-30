# Troubleshooting & Validation — Selective ERP Sent-Mail Archiving

> **Sanitized portfolio documentation.** This guide summarizes troubleshooting and validation performed in a Mailcow environment. All addresses, host identifiers, and log examples are illustrative. Do not paste production logs or confidential email content into a public repository.

## Scope

This guide covers two selective server-side archive flows:

- **HRM-generated mail:** a tagged Sender BCC copy is selected using a `Message-ID` pattern.
- **Warehouse/ERP-generated mail:** a tagged Sender BCC copy is selected using known subject patterns.

The normal message and the extra archive copy are separate. A Sieve `discard` inside the *tagged archive-copy branch* is intended to remove only a nonmatching BCC copy. Confirm this behavior in tests whenever changing the filter.

## 1. Identify the failure before changing settings

| Observation | Likely area to investigate | First check |
|---|---|---|
| Recipient did not receive the message | SMTP submission/delivery | Postfix logs, envelope sender/recipient, delivery status |
| Recipient received it; no copy in **Sent** in Outlook **or** SOGo | Missing Sent-folder storage by application | Determine whether application performs an IMAP append |
| Recipient received it; dedicated archive folder is empty | BCC, tag handling or Sieve matching | Sender BCC map and Sieve Prefilter |
| Extra archive copy appears in **Inbox** | Archive routing did not apply | Tagged-mail behavior, folder path and filter |
| Ordinary Outlook message enters application archive | Filter is too broad | Header/subject discriminator |

**Key distinction:** `SMTP submission/delivery` is not the same operation as `IMAP APPEND to Sent`. Do not treat a missing Sent copy as proof of failed delivery.

## 2. Confirm SMTP delivery

In the Mailcow administrative interface, inspect the relevant Postfix log entries. Correlate the test using the sender, recipient, approximate timestamp and (if available) queue or message identifiers. The following values are **fabricated examples**, not a copy of production logs:

```text
sasl_username=warehouse@example.com
from=<warehouse@example.com>
to=<recipient@example.net>
status=sent
```

Check that:

1. The application authenticated as the expected SMTP user.
2. The envelope sender and recipient were correct.
3. The message was accepted for delivery; the intended recipient actually received it.
4. The PDF attachment was present, where applicable.
5. There is no matching Sent copy in either Outlook or SOGo.

`status=sent` is useful transport evidence, but verify mailbox delivery separately when possible.

## 3. Recipient receives the message, but archive folder is empty

Check in this order:

1. **Sender BCC map:** Is the map active for the expected sender identity?
2. **BCC destination:** Does it point to the correct tagged address, e.g. `warehouse+dap@example.com` or `payroll+hrm@example.com`?
3. **Tagged-mail handling:** Is it set to **Do nothing**, allowing Sieve to control placement rather than automatic tagged subfolders?
4. **Prefilter:** Is the filter enabled for the correct mailbox, and does it validate successfully?
5. **Match condition:** Does the current message actually have the expected `Message-ID` characteristic or subject pattern?
6. **Destination folder:** Does the IMAP folder exist, with the exact spelling and capitalization used in `fileinto`?
7. **Folder visibility:** Check the destination directly in SOGo, not only in Outlook.

### HRM-specific checks

- Compare a *new* HRM-generated message with a normal Outlook message from the same account.
- Inspect their `Message-ID` formats; the documented implementation distinguished them using a workstation-related marker.
- If the application moves to another workstation or changes message generation, its previously observed marker may no longer match.
- Replace illustrative `@APPHOST` in documentation/examples only with a **verified** discriminator in the actual environment. Do not assume the illustrative marker works.

### Warehouse-specific checks

- Compare actual ERP-generated message subjects against all configured Sieve alternatives.
- An editable or newly formatted subject may not match; only the additional BCC copy then misses the archive.
- The shared warehouse mailbox was deliberately **not** identified by a single workstation hostname.
- Where supported operationally, standardize a stable application-specific subject prefix.

## 4. Extra BCC copy lands in Inbox

This usually indicates that the BCC copy is being created but is not being placed into the intended archive folder. Check the tagged-mail setting, the active Prefilter, the `envelope :detail` condition and the exact `fileinto` path.

Do not automatically delete Inbox messages until you have confirmed they are redundant archive copies and not original messages.

## 5. Normal Outlook mail appears in the ERP archive

The discriminator is too broad or an unexpected message matches it. Review the message headers and actual subject format, then narrow the condition. Possible evidence includes:

```text
Message-ID
X-Mailer
User-Agent
Subject
```

Do not presume every header is present or trustworthy. Validate against samples from **both** the business application and Outlook.

## 6. Positive and negative test matrix

Perform both tests after initial deployment and after every filter change.

| Test | Action | Expected observation |
|---|---|---|
| Positive — application | Send a real ERP/HRM message | Recipient receives it; attachment present if applicable; one archive copy in correct dedicated folder; no unexpected Inbox copy |
| Negative — Outlook | Send a normal message using the same mailbox | Recipient receives it; Outlook retains its normal Sent copy; **no** copy in the application-specific archive folder; no unexpected Inbox copy |

**Recorded outcome of the documented deployment:** positive and negative tests succeeded for the configured workflows. This does not guarantee matching for new message formats or future application upgrades.

## 7. Safe rollback

If selective archiving behaves unexpectedly:

1. **Disable the corresponding Sender BCC map first.** This stops generation of new archive copies while leaving ordinary SMTP sending in place.
2. Review and correct the Sieve Prefilter and tagged-mail settings.
3. Re-enable the BCC map only after validating the revised behavior.
4. Repeat both positive and negative tests.

**Avoid disabling only the Prefilter while leaving the BCC map enabled:** extra tagged copies could instead appear in Inbox. The intended rollback is to stop the BCC map first.

## 8. Operations and maintenance

- Re-test matching after an ERP/HRM upgrade, workstation migration or change to outbound subjects.
- Keep a private record of the actual mailbox mappings and active filter versions in an approved internal location, **not** in this repository.
- If selective archiving is business-critical, monitor its completeness separately from successful email delivery.
- Treat this as *selective operational archiving*, not as a guaranteed compliance archive or immutable audit trail.
- Validate Sieve code in Mailcow before saving; check folder names and mailbox-specific settings.

## Related documents

- [Project overview](../README.md)
- [Implementation guide](implementation.md)
- [HRM Sieve example](../examples/hrm-archive.sieve) *(to be added)*
- [Warehouse Sieve example](../examples/warehouse-archive.sieve) *(to be added)*

---

*All names and example data in this file are synthetic or generalized; the workflow description is based on the documented implementation.*
