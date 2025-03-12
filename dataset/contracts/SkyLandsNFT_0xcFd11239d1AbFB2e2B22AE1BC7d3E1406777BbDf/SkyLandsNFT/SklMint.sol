// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./SklPhases.sol";

contract SklMint is SklPhases {

    using SafeMath for uint256;

    uint public constant maxLandsPerAddress = 5;
    bool public mintAllowed = false;

    function toggleMint() external onlyOwner {
        mintAllowed = !mintAllowed;
    }

    function mint(address _to, uint _amount) external payable {
        require(mintAllowed, "Mint not allowed yet");
        require(_amount > 0);
        require(balanceOf(_to).add(_amount) <= maxLandsPerAddress, "Too much lands on address");
        require(totalSupply().add(_amount) <= getMaxSupply(), "All minted");

        uint actualPrice = getPriceForLands(_amount);
        // 5% for conversation rate possible change
        require(msg.value >= (actualPrice - actualPrice / 20), "Value is too low");

        for (uint _i = 0; _i < _amount; _i++) {
            uint tokenId = _createLand();
            _safeMint(_to, tokenId);
        }
    }

}
