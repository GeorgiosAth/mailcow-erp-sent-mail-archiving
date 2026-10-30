# Warehouse / ERP-generated email archive - sanitized Sieve prefilter example
# Portfolio example based on an implemented Mailcow configuration.
# NOT a drop-in production configuration: subject patterns are illustrative.
#
# Prerequisites (configured separately in Mailcow):
# - Sender BCC map: warehouse@example.com -> warehouse+dap@example.com
# - Tagged-mail handling: "Do nothing"
# - Existing IMAP folder: Sent/Shipping Documents
# - This script is a prefilter for warehouse@example.com
#
# Only additional BCC copies addressed to the +dap tag are classified here.
# Nonmatching tagged copies are discarded; the original message to the
# actual recipient is handled separately.
#
# Replace the English subject examples with verified, stable patterns before
# use. Broad subject matches can archive unrelated mail; changed subjects
# may cause an ERP archive copy to be discarded.

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
