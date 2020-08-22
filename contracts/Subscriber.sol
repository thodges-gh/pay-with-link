pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Subscriber
 * @notice NFT representing a service subscription
 * @dev This contract is deployed by the PaymentHandler
 */
contract Subscriber is ERC721 {
  using Counters for Counters.Counter;

  address public immutable handler;
  Counters.Counter private _tokenIds;

  /**
   * @param _name The name of the service
   * @param _symbol The symbol of the service
   */
  constructor(
    string memory _name,
    string memory _symbol
  )
    public
    ERC721(_name, _symbol)
  {
    handler = msg.sender;
  }

  /**
   * @notice Creates a new NFT representing a new subscription
   * @param _subscriber The address of the subscriber
   */
  function subscribe(
    address _subscriber
  )
    external
    onlyHandler()
    returns (uint256 _subscriberId)
  {
    _tokenIds.increment();
    _subscriberId = _tokenIds.current();
    _safeMint(_subscriber, _subscriberId);
  }

  /**
   * @notice Burns the provided subscription ID
   * @param _subscriberID the tokenId of the NFT
   */
  function burn(
    uint256 _subscriberId
  )
    external
    onlyHandler()
  {
    _burn(_subscriberId);
  }

  /**
   * @dev Reverts if msg.sender is not the handler
   */
  modifier onlyHandler() {
    require(msg.sender == handler, "!handler");
    _;
  }
}
