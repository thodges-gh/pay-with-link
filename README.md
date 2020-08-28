# Pay with LINK (a tokenized subscription service)

This contract enables services to accept LINK in order to create a subscription, providing the user with a NFT upon payment with a given expiration date. The user's NFTs can then be checked when connecting to a web3-enabled site to determine if that address has an active subscription. Subscriptions can be extended by providing a previous un-expired subscription ID in the data when making payment.

The owner of the contract, which would likely be the service provider, can set the payment amount and the subscription duration. The payment amount can be specified in either LINK or USD amount of LINK depending on if the feed address is set to the zero address or that of the [LINK/USD reference contract](https://feeds.chain.link/link-usd).

Since the subscription is based on an NFT, this means that subscriptions can be traded to other addresses if the user no longer wants it. Service providers should index NFT transfers and use the address of the user with the subscription for access.

## Service Providers

A service provider should subscribe to the SubscriptionToken's NewSubscription and Transfer events. A NewSubscription will always include the subscriber's address, a new subscriber ID, and the subscription's expiration timestamp. Transactions that emit NewSubscription will also emit a Transfer event where the from address is the 0 address.

Renewing a subscription will emit a NewSubscription as well, with the address of the subscriber, a new subscription ID, and an updated expiration timestamp. These will also emit two additional Transfer events, one to mint (the from address is the 0 address) and one to burn the previous subscription (the to address is the 0 address).

Trading subscriptions will emit a Transfer event where the from address is the address trading their subscription, and the to address is the address receiving their subscription. The subscription ID and its associated expiration timestamp should be carried over to the receiving address.

## Install

``` shell
npm install
```

## Test

``` shell
truffle test
```
