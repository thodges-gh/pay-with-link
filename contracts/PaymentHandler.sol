pragma solidity 0.6.12;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorInterface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Subscriber.sol";

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

  function setFeed(
    address _feed
  )
    public
    onlyOwner()
  {
    feed = AggregatorInterface(_feed);
    emit SetFeed(address(_feed));
  }

  function setPaymentAmount(
    uint256 _paymentAmount
  )
    public
    onlyOwner()
  {
    paymentAmount = _paymentAmount;
    emit SetPaymentAmount(_paymentAmount);
  }

  function setSubscribeDuration(
    uint256 _subscriptionDuration
  )
    public
    onlyOwner()
  {
    subscriptionDuration = _subscriptionDuration;
    emit SetSubscribeDuration(_subscriptionDuration);
  }

  function withdraw(
    uint256 _amount,
    address _recipient
  )
    external
    onlyOwner()
  {
    linkToken.transfer(_recipient, _amount);
  }

  function price() public view returns (uint256 _price) {
    // allows payment to be specified in LINK or USD
    if (address(feed) != address(0)) {
      uint256 currentPrice = uint256(feed.latestAnswer()).mul(10**10);
      _price = paymentAmount.mul(1 ether).div(currentPrice);
    } else {
      _price = paymentAmount;
    }

  }

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

  modifier onlyLINK() {
    require(msg.sender == address(linkToken), "!LINK");
    _;
  }
}
