pragma solidity 0.6.12;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorInterface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title SubscriptionToken
 * @notice NFT representing a service subscription. Deployed by a service provider,
 * allows NFTs to be issued representing a subscription. Subscriptions (NFTs) can
 * be traded to other addresses.
 */
contract SubscriptionToken is ERC721, Ownable {
  using Counters for Counters.Counter;
  using SafeMath for uint256;
  Counters.Counter private _subscriptionIds;

  LinkTokenInterface public immutable linkToken;
  AggregatorInterface public feed;
  uint256 public paymentAmount;
  uint256 public subscriptionDuration;
  mapping(uint256 => uint256) public subscriberExpiration;

  event NewSubscription(
    address indexed subscriber,
    uint256 indexed subscriberId,
    uint256 indexed endAt
  );
  event SetFeed(address feed);
  event SetPaymentAmount(uint256 paymentAmount);
  event SetSubscribeDuration(uint256 subscriptionDuration);

  /**
   * @notice Deploys the SubscriptionToken contract for the service provider
   * @param _link The address of the LINK token contract
   * @param _feed The address of the LINK/USD reference feed
   * @param _paymentAmount The amount of payment per subscription
   * @param _subscriptionDuration The length of time a subscription lasts
   * @param _name The name of the service
   * @param _symbol The symbol of the service
   */
  constructor(
    address _link,
    address _feed,
    uint256 _paymentAmount,
    uint256 _subscriptionDuration,
    string memory _name,
    string memory _symbol
  )
    public
    ERC721(_name, _symbol)
  {
    linkToken = LinkTokenInterface(_link);
    setPaymentAmount(_paymentAmount);
    setFeed(_feed);
    setSubscribeDuration(_subscriptionDuration);
  }

  /**
   * @notice Called by the LINK token on `transferAndCall`
   * @dev Subscriptions can be extended by providing the previous ID of
   * another active subscription owned by the sender. This will burn
   * the previous subscription ID.
   * @param _sender The address submitting payment
   * @param _amount The amount of LINK for payment
   * @param _data The uint256 encoded previous subscription ID (optional)
   */
  function onTokenTransfer(
    address _sender,
    uint256 _amount,
    bytes calldata _data
  )
    external
  {
    require(msg.sender == address(linkToken), "!LINK");
    // reverts if not enough payment supplied
    uint256 over = _amount.sub(price());
    uint256 subscriberId = subscribe(_sender);
    ( uint256 previousId ) = abi.decode(_data, (uint256));
    uint256 endAt;
    if (previousId > 0) {
      require(ownerOf(previousId) == _sender, "!owner");
      // reverts if previousId is expired
      uint256 extension = subscriberExpiration[previousId].sub(block.timestamp);
      endAt = subscriptionDuration.add(block.timestamp).add(extension);
      _burn(previousId);
    } else {
      endAt = subscriptionDuration.add(block.timestamp);
    }
    subscriberExpiration[subscriberId] = endAt;
    // refund if extra payment supplied
    if (over > 0) linkToken.transfer(_sender, over);
    emit NewSubscription(_sender, subscriberId, endAt);
  }

  /**
   * @notice Provides the amount of LINK to send for a subscription
   */
  function price() public view returns (uint256 _price) {
    // allows payment to be specified in LINK or USD
    if (address(feed) != address(0)) {
      uint256 currentPrice = uint256(feed.latestAnswer()).mul(1e10);
      _price = paymentAmount.mul(1e18).div(currentPrice);
    } else {
      _price = paymentAmount;
    }
  }

  /**
   * @notice Called by the owner to set the address of the LINK/USD reference feed
   * @dev This can be set to the 0 address to use direct LINK payment
   * @param _feed The address of the LINK/USD reference feed
   */
  function setFeed(
    address _feed
  )
    public
    onlyOwner()
  {
    feed = AggregatorInterface(_feed);
    if (_feed != address(0)) {
      assert(price() > 0);
    }
    emit SetFeed(_feed);
  }

  /**
   * @notice Called by the owner to set the payment amount
   * @dev The paymentAmount is denominated in USD if a feed is set
   * and directly in LINK if no feed is set
   * @param _paymentAmount The amount of payment per subscription
   */
  function setPaymentAmount(
    uint256 _paymentAmount
  )
    public
    onlyOwner()
  {
    paymentAmount = _paymentAmount;
    emit SetPaymentAmount(_paymentAmount);
  }

  /**
   * @notice Called by the owner to set the subscription duration
   * @param _subscriptionDuration The length of time a subscription lasts
   */
  function setSubscribeDuration(
    uint256 _subscriptionDuration
  )
    public
    onlyOwner()
  {
    require(_subscriptionDuration > 0, "!subscriptionDuration");
    subscriptionDuration = _subscriptionDuration;
    emit SetSubscribeDuration(_subscriptionDuration);
  }

  /**
   * @notice Called by the owner to withdraw LINK payment sent to this contract
   * @param _amount The amount of LINK to withdraw
   * @param _recipient The address to receive the LINK
   */
  function withdraw(
    uint256 _amount,
    address _recipient
  )
    external
    onlyOwner()
  {
    linkToken.transfer(_recipient, _amount);
  }

  /**
   * @notice Creates a new NFT representing a new subscription
   * @param _subscriber The address of the subscriber
   */
  function subscribe(
    address _subscriber
  )
    internal
    returns (uint256 _subscriberId)
  {
    _subscriptionIds.increment();
    _subscriberId = _subscriptionIds.current();
    _safeMint(_subscriber, _subscriberId);
  }
}
