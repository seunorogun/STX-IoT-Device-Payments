IoT Device Payments Smart Contract

Overview

This Clarity smart contract implements a machine-to-machine micropayment system for IoT devices, using a trait-based architecture. It allows IoT devices to register, send and receive payments, deposit and withdraw funds, and track balances securely on the Stacks blockchain.

The contract introduces a payment processor trait and a device manager trait to modularize functionality, enabling extensibility and interoperability with other contracts. It also applies a configurable contract fee to each transaction, ensuring sustainability for contract operations.

✨ Features

Device Registration & Management

Register devices on-chain with unique principals.

Activate or deactivate devices (by owner or contract admin).

Query device balances, active status, and total sent/received payments.

Micropayments Between Devices

Peer-to-peer STX micropayments with minimum payment thresholds.

Automatic fee deduction (default 5%, configurable up to 50%).

Balance adjustments for both payer and recipient.

Maintains a history of all transactions.

Funds Handling

Deposit STX into device balances.

Withdraw STX from device balances.

Contract ensures sufficient funds and validates all transactions.

Audit & Tracking

Store payment history (payer, recipient, timestamp, amount, fee, success).

Retrieve payment details for auditing.

Track total number of payments processed.

Admin Controls

Contract owner can update the transaction fee rate (capped at 50%).

Owner or device can deactivate a device.

⚙️ Key Constants & Errors

MIN_PAYMENT_AMOUNT = u1 → minimum allowed payment.

CONTRACT_OWNER = tx-sender → deployer has admin rights.

Error codes:

ERR_UNAUTHORIZED (u100) – unauthorized action.

ERR_INSUFFICIENT_FUNDS (u101) – balance too low.

ERR_DEVICE_NOT_REGISTERED (u102) – unknown device.

ERR_INVALID_AMOUNT (u103) – invalid payment/deposit/withdraw amount.

📑 Main Functions
Device Functions

register-device → registers a new device with zero balance.

is-device-active(device) → checks if a device is registered and active.

get-device-balance(device) → returns current STX balance.

deactivate-device(device) → disables a device (by admin or device itself).

Payment Functions

deposit-funds(amount) → deposit STX into sender’s balance.

process-payment(recipient, amount) → transfer funds between devices.

validate-payment(recipient, amount) → read-only check if payment is possible.

withdraw-funds(amount) → withdraw STX from device balance.

Admin / Utility

get-payment-history(payer, recipient, timestamp) → retrieve payment record.

get-total-payments → returns total number of processed payments.

get-fee-rate → returns the current contract fee percentage.

update-fee-rate(new-rate) → update fee (admin only, max 50%).

🔒 Security Considerations

Only registered devices can transact.

All payment amounts are validated against minimum and balance constraints.

Contract prevents unauthorized fee updates or device deactivation.

Fee deductions ensure sustainability without exceeding 50%.

🚀 Example Workflow

A new IoT device registers via register-device.

Device deposits STX using deposit-funds.

Device makes micropayments to another registered device via process-payment.

Fees are deducted automatically, and balances update accordingly.

Device owner can later withdraw funds using withdraw-funds.