const SubscriptionToken = artifacts.require('SubscriptionToken')
const { LinkToken } = require('@chainlink/contracts/truffle/v0.4/LinkToken')
const { MockV2Aggregator } = require('@chainlink/contracts/truffle/v0.6/MockV2Aggregator')
const { BN, constants, expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers')

contract('SubscriptionToken', (accounts) => {
  const maintainer = accounts[0]
  const user1 = accounts[1]
  const user2 = accounts[2]
  const stranger = accounts[3]

  const linkUsd = 77777777777
  const paymentAmount = 100000000
  const subscriptionDuration = 300
  const name = 'Service Name'
  const symbol = 'SYM'

  let subscriptionToken, link, feed

  beforeEach(async () => {
    LinkToken.setProvider(web3.currentProvider)
    MockV2Aggregator.setProvider(web3.currentProvider)
    link = await LinkToken.new({ from: maintainer })
    feed = await MockV2Aggregator.new(linkUsd, { from: maintainer })
    subscriptionToken = await SubscriptionToken.new(
      link.address,
      feed.address,
      paymentAmount,
      subscriptionDuration,
      name,
      symbol,
      { from: maintainer },
    )
  })

  describe('constructor', () => {
    it('deploys with the provided variables', async () => {
      assert.equal(feed.address, await subscriptionToken.feed())
      assert.equal(link.address, await subscriptionToken.linkToken())
      assert.equal(paymentAmount, await subscriptionToken.paymentAmount())
      assert.equal(subscriptionDuration, await subscriptionToken.subscriptionDuration())
    })
  })

  describe('setFeed', () => {
    context('when called by a stranger', () => {
      it('reverts', async () => {
        await expectRevert(
          subscriptionToken.setFeed(constants.ZERO_ADDRESS, { from: stranger }),
          'Ownable: caller is not the owner'
        )
      })
    })

    context('when called by the owner', () => {
      it('sets the feed address', async () => {
        const { receipt } = await subscriptionToken.setFeed(constants.ZERO_ADDRESS, { from: maintainer })
        assert.equal(constants.ZERO_ADDRESS, await subscriptionToken.feed())
        expectEvent(receipt, 'SetFeed', {
          feed: constants.ZERO_ADDRESS,
        })
      })

      context('when the feed address is invalid', () => {
        it('reverts', async () => {
          await expectRevert.unspecified(
            subscriptionToken.setFeed(user1, { from: maintainer }),
          )
        })
      })
    })
  })

  describe('setPaymentAmount', () => {
    context('when called by a stranger', () => {
      it('reverts', async () => {
        await expectRevert(
          subscriptionToken.setPaymentAmount(0, { from: stranger }),
          'Ownable: caller is not the owner'
        )
      })
    })

    context('when called by the owner', () => {
      it('sets the paymentAmount', async () => {
        const { receipt } = await subscriptionToken.setPaymentAmount(0, { from: maintainer })
        assert.equal(0, await subscriptionToken.paymentAmount())
        expectEvent(receipt, 'SetPaymentAmount', {
          paymentAmount: '0',
        })
      })
    })
  })

  describe('setSubscribeDuration', () => {
    context('when called by a stranger', () => {
      it('reverts', async () => {
        await expectRevert(
          subscriptionToken.setSubscribeDuration(301, { from: stranger }),
          'Ownable: caller is not the owner'
        )
      })
    })

    context('when called by the owner', () => {
      it('sets the subscriptionDuration', async () => {
        const { receipt } = await subscriptionToken.setSubscribeDuration(301, { from: maintainer })
        assert.equal(301, await subscriptionToken.subscriptionDuration())
        expectEvent(receipt, 'SetSubscribeDuration', {
          subscriptionDuration: '301',
        })
      })

      context('when the subscriptionDuration is invalid', () => {
        it('reverts', async () => {
          await expectRevert(
            subscriptionToken.setSubscribeDuration(0, { from: maintainer }),
            '!subscriptionDuration'
          )
        })
      })
    })
  })

  describe('withdraw', () => {
    beforeEach(async () => {
      await link.transfer(subscriptionToken.address, 1, { from: maintainer })
    })

    context('when called by a stranger', () => {
      it('reverts', async () => {
        await expectRevert(
          subscriptionToken.withdraw(1, stranger, { from: stranger }),
          'Ownable: caller is not the owner'
        )
      })
    })

    context('when called by the owner', () => {
      it('transfers the LINK to the recipient', async () => {
        assert.equal(0, await link.balanceOf(stranger))
        await subscriptionToken.withdraw(1, stranger, { from: maintainer })
        assert.equal(1, await link.balanceOf(stranger))
      })
    })
  })

  describe('onTokenTransfer', () => {
    context('when payment is specified in LINK', () => {
      beforeEach(async () => {
        await subscriptionToken.setFeed(constants.ZERO_ADDRESS, { from: maintainer })
        assert.equal(constants.ZERO_ADDRESS, await subscriptionToken.feed())
        await link.transfer(user1, 1, { from: maintainer })
        assert.equal(1, await link.balanceOf(user1))
        await link.transfer(user2, 3, { from: maintainer })
        assert.equal(3, await link.balanceOf(user2))
        await subscriptionToken.setPaymentAmount(2, { from: maintainer })
        assert.equal(2, await subscriptionToken.paymentAmount())
      })

      context('when not enough payment is provided', () => {
        it('reverts', async () => {
          await expectRevert.unspecified(
            link.transferAndCall(subscriptionToken.address, 1, constants.ZERO_BYTES32, { from: user1 })
          )
        })
      })

      context('when equal payment is provided', () => {
        it('creates a subscription', async () => {
          const { tx } = await link.transferAndCall(
            subscriptionToken.address,
            2,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          await expectEvent.inTransaction(tx, subscriptionToken, 'NewSubscription', {
            subscriber: user2,
            subscriberId: '1',
          })
          const expiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            expiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
        })
      })

      context('when too much payment is provided', () => {
        it('creates a subscription and sends extra payment back to the user', async () => {
          const { tx } = await link.transferAndCall(
            subscriptionToken.address,
            3,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          await expectEvent.inTransaction(tx, subscriptionToken, 'NewSubscription', {
            subscriber: user2,
            subscriberId: '1',
          })
          const expiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            expiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
          assert.equal(1, await link.balanceOf(user2))
        })
      })

      context('when a previous subscription is active', () => {
        let previousExpiration

        beforeEach(async () => {
          await link.transfer(user2, 1, { from: maintainer })
          assert.equal(4, await link.balanceOf(user2))
          await link.transferAndCall(
            subscriptionToken.address,
            2,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          previousExpiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            previousExpiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
        })

        it('extends the subscription and burns the previous subscription', async () => {
          await link.transferAndCall(
            subscriptionToken.address,
            2,
            web3.eth.abi.encodeParameter('uint256', 1),
            { from: user2 },
          )
          const expiration = await subscriptionToken.subscriberExpiration(2)
          assert.closeTo(
            new BN(subscriptionDuration).mul(new BN(2)).toNumber(),
            expiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
          await expectRevert(
            subscriptionToken.ownerOf(1),
            'ERC721: owner query for nonexistent token',
          )
        })
      })

      context('when a previous subscription is inactive', () => {
        let previousExpiration

        beforeEach(async () => {
          await link.transfer(user2, 1, { from: maintainer })
          assert.equal(4, await link.balanceOf(user2))
          await link.transferAndCall(
            subscriptionToken.address,
            2,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          previousExpiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            previousExpiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
          await time.increase(301)
        })

        it('reverts', async () => {
          await expectRevert.unspecified(
            link.transferAndCall(
              subscriptionToken.address,
              2,
              web3.eth.abi.encodeParameter('uint256', 1),
              { from: user2 },
            )
          )
        })
      })
    })

    context('when payment is specified in USD', () => {
      let price

      beforeEach(async () => {
        price = await subscriptionToken.price()
        await link.transfer(user1, price.sub(new BN(1)), { from: maintainer })
        assert.isTrue(price.sub(new BN(1)).eq(await link.balanceOf(user1)))
        await link.transfer(user2, price.mul(new BN(2)), { from: maintainer })
        assert.isTrue(price.mul(new BN(2)).eq(await link.balanceOf(user2)))
      })

      context('when not enough payment is provided', () => {
        it('reverts', async () => {
          await expectRevert.unspecified(
            link.transferAndCall(
              subscriptionToken.address,
              price.sub(new BN(1)),
              constants.ZERO_BYTES32,
              { from: user1 },
            )
          )
        })
      })

      context('when equal payment is provided', () => {
        it('creates a subscription', async () => {
          const { tx } = await link.transferAndCall(
            subscriptionToken.address,
            price,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          await expectEvent.inTransaction(tx, subscriptionToken, 'NewSubscription', {
            subscriber: user2,
            subscriberId: '1',
          })
          const expiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            expiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
        })
      })

      context('when too much payment is provided', () => {
        it('creates a subscription and sends extra payment back to the user', async () => {
          const { tx } = await link.transferAndCall(
            subscriptionToken.address,
            price.mul(new BN(2)),
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          await expectEvent.inTransaction(tx, subscriptionToken, 'NewSubscription', {
            subscriber: user2,
            subscriberId: '1',
          })
          assert.isTrue(price.eq(await link.balanceOf(user2)))
          const expiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            expiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
        })
      })

      context('when a previous subscription is active', () => {
        let previousExpiration

        beforeEach(async () => {
          await link.transferAndCall(
            subscriptionToken.address,
            price,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          previousExpiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            previousExpiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
        })

        it('extends the subscription and burns the previous subscription', async () => {
          await link.transferAndCall(
            subscriptionToken.address,
            price,
            web3.eth.abi.encodeParameter('uint256', 1),
            { from: user2 },
          )
          const expiration = await subscriptionToken.subscriberExpiration(2)
          assert.closeTo(
            new BN(subscriptionDuration).mul(new BN(2)).toNumber(),
            expiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
          await expectRevert(
            subscriptionToken.ownerOf(1),
            'ERC721: owner query for nonexistent token',
          )
        })
      })

      context('when a previous subscription is inactive', () => {
        let previousExpiration

        beforeEach(async () => {
          await link.transferAndCall(
            subscriptionToken.address,
            price,
            constants.ZERO_BYTES32,
            { from: user2 },
          )
          previousExpiration = await subscriptionToken.subscriberExpiration(1)
          assert.closeTo(
            subscriptionDuration,
            previousExpiration.sub(new BN(await time.latest())).toNumber(),
            20,
          )
          await time.increase(301)
        })

        it('reverts', async () => {
          await expectRevert.unspecified(
            link.transferAndCall(
              subscriptionToken.address,
              price,
              web3.eth.abi.encodeParameter('uint256', 1),
              { from: user2 },
            )
          )
        })
      })
    })
  })
})
