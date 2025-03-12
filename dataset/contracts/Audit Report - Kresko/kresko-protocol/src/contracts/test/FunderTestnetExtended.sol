// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {MockERC20} from "./MockERC20.sol";
import {WETH} from "./WETH.sol";
import {IAccountStateFacet} from "../minter/interfaces/IAccountStateFacet.sol";

/* solhint-disable no-empty-blocks */

struct Token {
    uint256 amount;
    address token;
}

contract FunderTestnetExtended {
    mapping(address => bool) public owners;
    mapping(address => bool) public funded;
    IAccountStateFacet public kresko;
    MockERC20 public tokenToFund;
    uint256 public fundAmount = 10000 ether;
    event Funded(address indexed account);

    constructor(address _kresko, address _tokenToFund) {
        owners[msg.sender] = true;
        kresko = IAccountStateFacet(_kresko);
        tokenToFund = MockERC20(_tokenToFund);
    }

    function toggleOwners(address[] calldata accounts) external {
        require(owners[msg.sender], "!o");
        for (uint256 i; i < accounts.length; i++) {
            owners[accounts[i]] = !owners[accounts[i]];
        }
    }

    function isEligible(address account) public view returns (bool) {
        return !funded[account];
    }

    function setFundAmount(uint256 amount) external {
        require(owners[msg.sender], "!o");
        fundAmount = amount;
    }

    function distribute() external {
        if (!isEligible(msg.sender)) return;
        tokenToFund.mint(msg.sender, fundAmount);
        funded[msg.sender] = true;
        emit Funded(msg.sender);
    }

    function drain() external {
        require(owners[msg.sender], "!o");
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}
}
