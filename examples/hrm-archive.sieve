# HRM-generated email archive — sanitized Sieve prefilter example
# Portfolio example based on a production Mailcow configuration.
# This is NOT a drop-in production configuration.
#
# Prerequisites (configured separately in Mailcow):
# - Sender BCC map for payroll@example.com -> payroll+hrm@example.com
# - Tagged-mail handling set to "Do nothing"
# - An existing IMAP folder named "Sent/Pylon HRM"
# - Prefilter assigned to the payroll@example.com mailbox
#
# Replace @APPHOST with a verified, application-specific Message-ID pattern
# before deploying. The real production workstation identifier is omitted.
# If the pattern changes, unmatched extra BCC copies are discarded.
# The original outbound message is handled separately.

require ["fileinto", "envelope", "subaddress"];

if envelope :detail :is "to" "hrm" {
    if header :contains "Message-ID" "@APPHOST" {
        fileinto "Sent/Pylon HRM";
    } else {
        discard;
    }
    stop;
}
