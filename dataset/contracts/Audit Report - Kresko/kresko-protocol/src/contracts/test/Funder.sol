// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IERC20Permit} from "../shared/IERC20Permit.sol";
import {WETH} from "./WETH.sol";
import {IAccountStateFacet} from "../minter/interfaces/IAccountStateFacet.sol";

/* solhint-disable no-empty-blocks */

struct Token {
    uint256 amount;
    address token;
}

contract Funder {
    mapping(address => bool) public owners;
    mapping(address => bool) public funded;
    IAccountStateFacet public kresko;

    event Funded(address indexed account);

    constructor(address _kresko) {
        owners[msg.sender] = true;
        kresko = IAccountStateFacet(_kresko);
    }

    function toggleOwners(address[] calldata accounts) external {
        require(owners[msg.sender], "!o");
        for (uint256 i; i < accounts.length; i++) {
            owners[accounts[i]] = !owners[accounts[i]];
        }
    }

    function isEligible(address account) public view returns (bool) {
        return account.balance < 0.001 ether && kresko.getAccountKrAssetValue(account) > 0 && !funded[account];
    }

    function distribute(address[] calldata accounts, uint256 ethAmount) external {
        require(owners[msg.sender], "!o");
        for (uint256 i; i < accounts.length; i++) {
            if (!isEligible(accounts[i])) continue;

            funded[accounts[i]] = true;
            payable(accounts[i]).transfer(ethAmount);
            emit Funded(accounts[i]);
        }
    }

    function drain() external {
        require(owners[msg.sender], "!o");
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}
}
