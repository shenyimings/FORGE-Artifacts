//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GVSToken is ERC20, Ownable, Pausable {
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public whitelisted;

    constructor(address _ownerAddress) ERC20("GVS Token", "GVS") {
        _mint(_ownerAddress, 500000000 ether);
        setWhitelisted(_ownerAddress, true);
        _transferOwnership(_ownerAddress);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(
            !paused() || whitelisted[from] || whitelisted[to],
            "GVS: token transfer while paused"
        );
        require(
            !blacklisted[from] && !blacklisted[to],
            "GVS: address is blacklisted"
        );
    }

    /* Owner features */
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setBlacklist(address addr, bool state) public onlyOwner {
        blacklisted[addr] = state;
    }

    function setWhitelisted(address addr, bool state) public onlyOwner {
        whitelisted[addr] = state;
    }

    function withdrawBNB() external onlyOwner returns (bool) {
        require(address(this).balance > 0, "GVSToken: No balance to withdraw");
        return payable(owner()).send(address(this).balance);
    }

    function withdrawERC20(address addr) external onlyOwner returns (bool) {
        IERC20 tokenContract = IERC20(addr);
        require(
            tokenContract.balanceOf(address(this)) > 0,
            "GVSToken: No erc20 balance"
        );
        return
            tokenContract.transfer(
                owner(),
                tokenContract.balanceOf(address(this))
            );
    }
}
