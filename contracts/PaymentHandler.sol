pragma solidity 0.6.12;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorInterface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Subscriber.sol";

/**
 * @title PaymentHandler
 * @notice Deployed by a service provider, allows NFTs to be issued representing
 * a subscription.
 */
contract PaymentHandler is Ownable {
  using SafeMath for uint256;

  LinkTokenInterface public immutable linkToken;
  Subscriber public immutable subscriber;
  AggregatorInterface public feed;
  uint256 public paymentAmount;
  uint256 public subscriptionDuration;

  mapping(uint256 => uint256) public subscriberExpiration;

  event NewSubscription(address indexed subscriber, uint256 subscriberId, uint256 endAt);
  event SetFeed(address feed);
  event SetPaymentAmount(uint256 paymentAmount);
  event SetSubscribeDuration(uint256 subscriptionDuration);

  /**
   * @notice Deploys the contract specific to the service provider, also deploys
   * a NFT contract specific to the service
   * @param _link The address of the LINK token contract
   * @param _feed The address of the LINK/USD reference feed
   * @param _paymentAmount The amount of payment per subscription
   * @param _subscriptionDuration The length of time a subscription lasts
   * @param _name The name of the service (for NFT)
   * @param _symbol The symbol of the service (for NFT)
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
  {
    linkToken = LinkTokenInterface(_link);
    setFeed(_feed);
    setPaymentAmount(_paymentAmount);
    setSubscribeDuration(_subscriptionDuration);
    subscriber = new Subscriber(_name, _symbol);
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
    emit SetFeed(address(_feed));
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
   * @notice Provides the amount of LINK to send for a subscription
   */
  function price() public view returns (uint256 _price) {
    // allows payment to be specified in LINK or USD
    if (address(feed) != address(0)) {
      uint256 currentPrice = uint256(feed.latestAnswer()).mul(10**10);
      _price = paymentAmount.mul(1 ether).div(currentPrice);
    } else {
      _price = paymentAmount;
    }

  }

  /**
   * @notice Called by the LINK token on `transferAndCall`
   * @dev Subscriptions can be extended by providing the previous ID of
   * another active subscription owned by the sender
   * @param _sender The address submitting payment
   * @param _amount The amount of LINK for payment
   * @param _data The encoded previous subscription ID (optional)
   */
  function onTokenTransfer(
    address _sender,
    uint256 _amount,
    bytes calldata _data
  )
    external
    onlyLINK()
  {
    // reverts if not enough payment supplied
    uint256 over = _amount.sub(price());
    uint256 subscriberId = subscriber.subscribe(_sender);
    ( uint256 previousId ) = abi.decode(_data, (uint256));
    uint256 endAt;
    if (previousId > 0) {
      require(subscriber.ownerOf(previousId) == _sender, "!owner");
      // reverts if previousId is expired
      uint256 extension = subscriberExpiration[previousId].sub(block.timestamp);
      endAt = subscriptionDuration.add(block.timestamp).add(extension);
      subscriber.burn(previousId);
    } else {
      endAt = subscriptionDuration.add(block.timestamp);
    }
    subscriberExpiration[subscriberId] = endAt;
    // refund if extra payment supplied
    if (over > 0) linkToken.transfer(_sender, over);
    emit NewSubscription(_sender, subscriberId, endAt);
  }

  /**
   * @dev Reverts if msg.sender is not the LINK token
   */
  modifier onlyLINK() {
    require(msg.sender == address(linkToken), "!LINK");
    _;
  }
}
