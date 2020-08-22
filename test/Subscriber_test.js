const Subscriber = artifacts.require('Subscriber')
const PaymentHandler = artifacts.require('PaymentHandler')
const { LinkToken } = require('@chainlink/contracts/truffle/v0.4/LinkToken')
const { MockV2Aggregator } = require('@chainlink/contracts/truffle/v0.6/MockV2Aggregator')
const { constants, expectRevert } = require('@openzeppelin/test-helpers')

contract('Subscriber', (accounts) => {
  const maintainer = accounts[0]
  const user1 = accounts[1]

  const linkUsd = 77777777777
  const paymentAmount = 100000000
  const subscriptionDuration = 300
  const name = 'Service Name'
  const symbol = 'SYM'

  let paymentHandler, subscriber, link, feed

  beforeEach(async () => {
    MockV2Aggregator.setProvider(web3.currentProvider)
    LinkToken.setProvider(web3.currentProvider)
    feed = await MockV2Aggregator.new(linkUsd, { from: maintainer })
    link = await LinkToken.new({ from: maintainer })
    paymentHandler = await PaymentHandler.new(
      link.address,
      feed.address,
      paymentAmount,
      subscriptionDuration,
      name,
      symbol,
      { from: maintainer },
    )
    subscriber = await Subscriber.at(await paymentHandler.subscriber())
  })

  describe('subscribe', () => {
    it('reverts when called directly', async () => {
      await expectRevert(
        subscriber.subscribe(maintainer, { from: maintainer }),
        '!handler'
      )
    })
  })

  describe('burn', () => {
    let price

    beforeEach(async () => {
      price = await paymentHandler.price()
      await link.transfer(user1, price, { from: maintainer })
      assert.isTrue(price.eq(await link.balanceOf(user1)))
      await link.transferAndCall(
        paymentHandler.address,
        price,
        constants.ZERO_BYTES32,
        { from: user1 },
      )
    })

    it('reverts when called directly', async () => {
      await expectRevert(
        subscriber.burn(1, { from: maintainer }),
        '!handler'
      )
    })
  })
})
