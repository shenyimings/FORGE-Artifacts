pragma solidity ^0.4.18;

import "./REIDAOMintableToken.sol";

contract REIToken is REIDAOMintableToken {
  string public name = "REI Token";
  string public symbol = "REI";

  address public wallet;
  mapping (uint => bool) tokensReleased;
  event WaveReleased(uint wave, uint amount);

  /**
   * @dev initializes contract
   * @param _wallet address the address of REIDAO's wallet
   */
  function REIToken(address _wallet) public {
    wallet = _wallet;
  }

  /**
   * @dev changes REIDAO wallet, can be called by owners.
   */
  function changeWallet(address _wallet) public ownerOnly {
    wallet = _wallet;
  }

  /**
   * @dev disburses REI token allocated to REIDAO. this prevents multiple disbursements
   *   of the same period.
   */
  function disburseToREIDAO() public ownerOnly {
    uint index;
    uint amount = 200000 * 10**decimals;
    bool toMint;
    if (!tokensReleased[index]) {
      //for WAVE 1 - immediate
      toMint = true;
    } else {
      if (block.timestamp >= 1577836800) {
        //for WAVE 2 - after 01/01/2020 @ 12:00am (UTC)
        index = 1;
        if (!tokensReleased[index]) {
          toMint = true;
        } else {
          if (block.timestamp >= 1609459200) {
            //for WAVE 3 - after 01/01/2021 @ 12:00am (UTC)
            index = 2;
            if (!tokensReleased[index]) {
              toMint = true;
            } else {
              if (block.timestamp >= 1640995200) {
                //for WAVE 4 - after 01/01/2022 @ 12:00am (UTC)
                index = 3;
                amount = 150000 * 10**decimals;
                require(!tokensReleased[index]);
                toMint = true;
              }
            }
          }
        }
      }
    }
    if (toMint) {
      mint(wallet, amount);
      tokensReleased[index] = true;
      WaveReleased(index, amount);
    }
  }
}
