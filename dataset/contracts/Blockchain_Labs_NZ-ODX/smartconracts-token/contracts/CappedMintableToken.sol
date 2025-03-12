pragma solidity ^0.4.23;

import "./StandardToken.sol";


/**
 * @title CappedMintableToken token
 */
contract CappedMintableToken is StandardToken {
  event Mint(address indexed to, uint256 amount);
  event MintFinished();
  event MintingAgentChanged(address addr, bool state);

  uint256 public cap;

  bool public mintingFinished = false;
  mapping (address => bool) public mintAgents;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }
  
  modifier onlyMintAgent() {
    // crowdsale contracts or owner are allowed to mint new tokens
    if(!mintAgents[msg.sender] && (msg.sender != owner)) {
        revert();
    }
    _;
  }


  constructor(uint256 _cap) public {
    require(_cap > 0);
    cap = _cap;
  }


  /**
   * Owner can allow a crowdsale contract to mint new tokens.
   */
  function setMintAgent(address addr, bool state) onlyOwner canMint public {
    mintAgents[addr] = state;
    emit MintingAgentChanged(addr, state);
  }
  
  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyMintAgent canMint isRunning public returns (bool) {
    require(totalSupply_.add(_amount) <= cap);
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
    return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyOwner canMint public returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }
}
