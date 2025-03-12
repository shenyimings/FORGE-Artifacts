// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract nucleon_token is ERC20, Initializable {
  // ======================== configs =========================
    ERC20 token;
    string  _name;
    string  _symbol;

  constructor() ERC20("Nucleon Governance Token", "NUT") {
    _mint(msg.sender, 300000000000000000000000);
  }
  // function initialize(ERC20 _token) public initializer {
  //       token = _token;
  //       _name = "Nucleon Governance Token";
  //       _symbol = "NUT";
  //       _mint(msg.sender, 300000000000000000000000);
  // }
  // /**
  //    * @dev Returns the name of the token.
  //    */
  // function name() public view virtual override returns (string memory) {
  //   return _name;
  // }

  //   /**
  //    * @dev Returns the symbol of the token, usually a shorter version of the
  //    * name.
  //    */
  // function symbol() public view virtual override returns (string memory) {
  //     return _symbol;
  // }
}
