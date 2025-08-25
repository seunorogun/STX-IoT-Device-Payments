;; IoT Device Payments Smart Contract
;; Manages machine-to-machine micropayments with trait-based architecture

;; Define payment processor trait
(define-trait payment-processor
  (
    (process-payment (principal uint) (response uint uint))
    (validate-payment (principal uint) (response bool uint))
  )
)

;; Define device management trait  
(define-trait device-manager
  (
    (register-device (principal) (response bool uint))
    (is-device-active (principal) (response bool uint))
    (get-device-balance (principal) (response uint uint))
  )
)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_DEVICE_NOT_REGISTERED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant MIN_PAYMENT_AMOUNT u1)

;; Data variables
(define-data-var total-payments uint u0)
(define-data-var contract-fee-rate uint u5) ;; 5% fee

;; Data maps
(define-map registered-devices principal 
  {
    active: bool,
    balance: uint,
    total-received: uint,
    total-sent: uint
  }
)

(define-map payment-history 
  { payer: principal, recipient: principal, timestamp: uint }
  {
    amount: uint,
    fee: uint,
    success: bool
  }
)

;; Device registration function
(define-public (register-device)
  (let ((device tx-sender))
    (map-set registered-devices device
      {
        active: true,
        balance: u0,
        total-received: u0,
        total-sent: u0
      }
    )
    (ok true)
  )
)

;; Check if device is registered and active
(define-read-only (is-device-active (device principal))
  (match (map-get? registered-devices device)
    device-info (ok (get active device-info))
    (err ERR_DEVICE_NOT_REGISTERED)
  )
)

;; Get device balance
(define-read-only (get-device-balance (device principal))
  (match (map-get? registered-devices device)
    device-info (ok (get balance device-info))
    (err ERR_DEVICE_NOT_REGISTERED)
  )
)

;; Deposit STX to device balance
(define-public (deposit-funds (amount uint))
  (let (
    (device tx-sender)
    (current-info (unwrap! (map-get? registered-devices device) ERR_DEVICE_NOT_REGISTERED))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (map-set registered-devices device
      (merge current-info { balance: (+ (get balance current-info) amount) })
    )
    (ok amount)
  )
)

;; Process micropayment between devices
(define-public (process-payment (recipient principal) (amount uint))
  (let (
    (payer tx-sender)
    (fee (/ (* amount (var-get contract-fee-rate)) u100))
    (net-amount (- amount fee))
    (payer-info (unwrap! (map-get? registered-devices payer) ERR_DEVICE_NOT_REGISTERED))
    (recipient-info (unwrap! (map-get? registered-devices recipient) ERR_DEVICE_NOT_REGISTERED))
    (timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Validate payment
    (asserts! (>= amount MIN_PAYMENT_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (get active payer-info) ERR_DEVICE_NOT_REGISTERED)
    (asserts! (get active recipient-info) ERR_DEVICE_NOT_REGISTERED)
    (asserts! (>= (get balance payer-info) amount) ERR_INSUFFICIENT_FUNDS)

    ;; Update payer balance
    (map-set registered-devices payer
      (merge payer-info 
        { 
          balance: (- (get balance payer-info) amount),
          total-sent: (+ (get total-sent payer-info) amount)
        }
      )
    )

    ;; Update recipient balance
    (map-set registered-devices recipient
      (merge recipient-info 
        { 
          balance: (+ (get balance recipient-info) net-amount),
          total-received: (+ (get total-received recipient-info) net-amount)
        }
      )
    )

    ;; Record payment history
    (map-set payment-history 
      { payer: payer, recipient: recipient, timestamp: timestamp }
      {
        amount: amount,
        fee: fee,
        success: true
      }
    )

    ;; Update total payments counter
    (var-set total-payments (+ (var-get total-payments) u1))

    (ok net-amount)
  )
)

;; Validate payment parameters
(define-read-only (validate-payment (recipient principal) (amount uint))
  (let (
    (payer tx-sender)
    (payer-info (map-get? registered-devices payer))
    (recipient-info (map-get? registered-devices recipient))
  )
    (and 
      (>= amount MIN_PAYMENT_AMOUNT)
      (is-some payer-info)
      (is-some recipient-info)
      (match payer-info 
        info (>= (get balance info) amount)
        false
      )
    )
  )
)

;; Withdraw funds from device balance
(define-public (withdraw-funds (amount uint))
  (let (
    (device tx-sender)
    (device-info (unwrap! (map-get? registered-devices device) ERR_DEVICE_NOT_REGISTERED))
  )
    (asserts! (>= (get balance device-info) amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (try! (as-contract (stx-transfer? amount tx-sender device)))

    (map-set registered-devices device
      (merge device-info { balance: (- (get balance device-info) amount) })
    )
    (ok amount)
  )
)

;; Get payment history
(define-read-only (get-payment-history (payer principal) (recipient principal) (timestamp uint))
  (map-get? payment-history { payer: payer, recipient: recipient, timestamp: timestamp })
)

;; Get total payments processed
(define-read-only (get-total-payments)
  (var-get total-payments)
)

;; Get contract fee rate
(define-read-only (get-fee-rate)
  (var-get contract-fee-rate)
)

;; Admin function to update fee rate (only contract owner)
(define-public (update-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u50) ERR_INVALID_AMOUNT) ;; Max 50% fee
    (var-set contract-fee-rate new-rate)
    (ok new-rate)
  )
)

;; Deactivate device (only contract owner or device itself)
(define-public (deactivate-device (device principal))
  (let ((device-info (unwrap! (map-get? registered-devices device) ERR_DEVICE_NOT_REGISTERED)))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender device)) ERR_UNAUTHORIZED)

    (map-set registered-devices device
      (merge device-info { active: false })
    )
    (ok true)
  )
)