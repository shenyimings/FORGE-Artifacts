//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Banana is ERC20("BANANA", "BNS"), Ownable {
    uint256 public constant ONE_BANANA = 1e18;
    uint256 public constant NUM_PROMOTIONAL_BANANA = 1_500_000;
    uint256 public constant NUM_BANANA_TREE_LP = 20_000_000;

    uint256 public NUM_BANANA_BNB_LP = 50_000_000;

    address public caveAddress;
    address public forestAddress;
    address public apeAddress;
    address public upgradeAddress;

    bool public promotionalBananaMinted = false;
    bool public bnbLPBananaMinted = false;
    bool public treeLPBananaMinted = false;

    // ADMIN

    /**
     * forest yields banana
     */
    function setForestAddress(address _forestAddress) external onlyOwner {
        forestAddress = _forestAddress;
    }

    function setCaveAddress(address _caveAddress) external onlyOwner {
        caveAddress = _caveAddress;
    }

    function setUpgradeAddress(address _upgradeAddress) external onlyOwner {
        upgradeAddress = _upgradeAddress;
    }

    /**
     * ape consumes banana
     * ape address can only be set once
     */
    function setApeAddress(address _apeAddress) external onlyOwner {
        require(address(apeAddress) == address(0), "ape address already set");
        apeAddress = _apeAddress;
    }

    function mintPromotionalBanana(address _to) external onlyOwner {
        require(!promotionalBananaMinted, "promotional banana has already been minted");
        promotionalBananaMinted = true;
        _mint(_to, NUM_PROMOTIONAL_BANANA * ONE_BANANA);
    }

    function mintBnbLPBanana() external onlyOwner {
        require(!bnbLPBananaMinted, "bnb banana LP has already been minted");
        bnbLPBananaMinted = true;
        _mint(owner(), NUM_BANANA_BNB_LP * ONE_BANANA);
    }

    function mintTreeLPBanana() external onlyOwner {
        require(!treeLPBananaMinted, "tree banana LP has already been minted");
        treeLPBananaMinted = true;
        _mint(owner(), NUM_BANANA_TREE_LP * ONE_BANANA);
    }
    
    // external

    function mint(address _to, uint256 _amount) external {
        require(forestAddress != address(0) && apeAddress != address(0) && caveAddress != address(0) && upgradeAddress != address(0), "missing initial requirements");
        require(_msgSender() == forestAddress,"msgsender does not have permission");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(apeAddress != address(0) && caveAddress != address(0) && upgradeAddress != address(0), "missing initial requirements");
        require(
            _msgSender() == apeAddress 
            || _msgSender() == caveAddress 
            || _msgSender() == upgradeAddress,
            "msgsender does not have permission"
        );
        _burn(_from, _amount);
    }

    function transferToCave(address _from, uint256 _amount) external {
        require(caveAddress != address(0), "missing initial requirements");
        require(_msgSender() == caveAddress, "only the cave contract can call transferToCave");
        _transfer(_from, caveAddress, _amount);
    }

    function transferForUpgradesFees(address _from, uint256 _amount) external {
        require(upgradeAddress != address(0), "missing initial requirements");
        require(_msgSender() == upgradeAddress, "only the upgrade contract can call transferForUpgradesFees");
        _transfer(_from, upgradeAddress, _amount);
    }
}