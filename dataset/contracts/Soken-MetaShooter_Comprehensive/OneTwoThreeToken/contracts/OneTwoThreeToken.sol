// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VestingWallet.sol";
import "./MonthlyVestingWallet.sol";
import "./MonthlyVestingMultiWallet.sol";


contract OneTwoThreeToken is Ownable, ERC20 {
    constructor() ERC20("123swap finance", "123") {
        createVestingMultiWallets();
        _mint(owner(), privateTokensPreMinted);
    }

    /// Private Sale 19%
    uint256 constant public privateTokensPreMinted = 24510000000000000000000000; // 24 510 000 * 10**18

    /// Public Sale 2%
    uint256 constant public publicTokens = 2580000000000000000000000; // 2 580 000 * 10**18

    // Marketing / Ecosystem 15%
    uint256 constant public marketingTokens = 19350000000000000000000000; // 19 350 000 * 10**18

    // Team 14%
    uint256 constant public teamTokens = 18060000000000000000000000; // 18 060 000 * 10**18

    // Partners / Advisers 6%
    uint256 constant public partnerTokens = 7740000000000000000000000; // 7 740 000 * 10**18

    // Development / Treasury 25%
    uint256 constant public treasuryTokens = 32250000000000000000000000; // 32 250 000 * 10**18

    // Liquidity 19%
    uint256 constant public liquidityTokens = 24510000000000000000000000; // 24 510 000 * 10**18

    address public marketingVestingWallet;
    address public teamVestingWallet;
    address public partnerVestingWallet;
    address public treasuryVestingWallet;
    address public liquidityVestingWallet;

    MonthlyVestingMultiWallet public publicVestingWallet;

    bool public saleFinished = false;

    // May 2, 2022 12:00:00
    uint256 public constant dateSaleEnd = 1651492800;

    modifier beforeEnd {
        require(!saleFinished);
        _;
    }

    function close() public onlyOwner beforeEnd {
        generateTeamTokens();
        generateMarketingTokens();
        generatePartnerTokens();
        generateTreasuryTokens();
        generateLiquidityTokens();
        saleFinished = true;
    }

    function createVestingMultiWallets() internal{
        publicVestingWallet = new MonthlyVestingMultiWallet(address(this), uint64(dateSaleEnd), 1, 19, 10);
    }

    function generateMarketingTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 1, 16);
        marketingVestingWallet = address(lockedTokens);
        uint256 initialMintedTokens = marketingTokens * 15 / 100;
        _mint(owner(), initialMintedTokens);
        _mint(marketingVestingWallet, marketingTokens-initialMintedTokens);
    }

    function generateTeamTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 12, 24);
        teamVestingWallet = address(lockedTokens);
        _mint(teamVestingWallet, teamTokens);
    }    

    function generatePartnerTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 0, 32);
        partnerVestingWallet = address(lockedTokens);
        _mint(partnerVestingWallet, partnerTokens);
    }    
    
    function generateTreasuryTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 0, 32);
        treasuryVestingWallet = address(lockedTokens);
        _mint(treasuryVestingWallet, treasuryTokens);
    }    
    
    function generateLiquidityTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 1, 17);
        liquidityVestingWallet = address(lockedTokens);
        uint256 initialMintedTokens = liquidityTokens * 10 / 100;
        _mint(owner(), initialMintedTokens);
        _mint(liquidityVestingWallet, liquidityTokens-initialMintedTokens);
    }

    function buyPublicTokensOnInvestorBehalf(address _beneficiary, uint256 _tokens) public onlyOwner beforeEnd {
        require(balanceOf(address(publicVestingWallet)) + _tokens <= publicTokens, "OneTwoThreeToken: all public tokens sold");
        publicVestingWallet.buy(_beneficiary, _tokens);
        _mint(address(publicVestingWallet), _tokens);
    }

    function buyPublicTokensOnInvestorBehalfBatch(address[] calldata _addresses, uint256[] calldata _tokens) public onlyOwner beforeEnd {
        require(_addresses.length == _tokens.length);
        require(_addresses.length <= 100);

        for (uint256 i = 0; i < _tokens.length; i++) {
            buyPublicTokensOnInvestorBehalf(_addresses[i], _tokens[i]);
        }
    }


}