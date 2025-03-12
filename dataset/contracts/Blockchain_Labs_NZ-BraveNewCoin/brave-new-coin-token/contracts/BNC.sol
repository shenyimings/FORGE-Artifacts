pragma solidity ^0.4.11;

import "./MiniMeToken.sol";

contract BNC is MiniMeToken {
  function BNC(address _tokenFactory)
      MiniMeToken(
        _tokenFactory,
        0x0,               // no parent token
        0,                 // no snapshot block number from parent
        "Brave New Coin",  // Token name
        12,                // Decimals
        "BNC",             // Symbol
        true               // Enable transfers
      ) {
        generateTokens(msg.sender, 100000000000000000000);
      }
}
