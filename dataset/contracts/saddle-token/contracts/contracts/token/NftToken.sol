// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract NftToken is ERC20Votes {
    address public deployer;

    constructor() ERC20Permit("NFT.com") ERC20("NFT.com", "NFT") {
        _mint(msg.sender, 10 * 10**9 * 10**18);
        deployer = msg.sender;
    }

    /**
     @notice allows token burns (protocol fees)
     @param _amount amount of NFT.com tokens to burn
    */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function deprecateDeployer() external {
        require(msg.sender == deployer);
        deployer = address(0x0);
    }

    function teamTransfer(address[] calldata _recipients, uint256[] calldata _amounts) external {
        require(msg.sender == deployer);
        require(_recipients.length == _amounts.length);

        for (uint256 i = 0; i < _recipients.length; i++) {
            _transfer(deployer, _recipients[i], _amounts[i]);
            _transfer(_recipients[i], deployer, _amounts[i]);
        }
    }
}
