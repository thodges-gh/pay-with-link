pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Subscriber is ERC721 {
  using Counters for Counters.Counter;

  address public immutable handler;
  Counters.Counter private _tokenIds;

  constructor(
    string memory _name,
    string memory _symbol
  )
    public
    ERC721(_name, _symbol)
  {
    handler = msg.sender;
  }

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

  function burn(
    uint256 _subscriberId
  )
    external
    onlyHandler()
  {
    _burn(_subscriberId);
  }

  modifier onlyHandler() {
    require(msg.sender == handler, "!handler");
    _;
  }
}
