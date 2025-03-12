// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable.sol";

contract HasNoEther is Ownable {
    /**
     * @dev Constructor that rejects incoming Ether
     * @dev The `payable` flag is added so we can access `msg.value` without compiler warning. If we
     * leave out payable, then Solidity will allow inheriting contracts to implement a payable
     * constructor. By doing it this way we prevent a payable constructor from working. Alternatively
     * we could use assembly to access msg.value.
     */
    constructor() payable {
        require(msg.value == 0, "HasNoEther: cannot send ETH when deploying");
    }

    function reclaimEther() external virtual onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        require(success, "HasNoEther: transfer failed");
    }
}
