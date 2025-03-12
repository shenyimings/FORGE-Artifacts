// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
//import './Multicall.sol';

interface IFactory {
    function totalDeployed() external view returns (uint256 length);
    function tokensDeployed(uint256 index) external view returns (address gbt);
    function gumballsDeployed(uint256 index) external view returns (address gumball);
}

interface IBondingCurve {
    function currentPrice() external view returns (uint256);
    function buy(uint256 _amountBASE, uint256 _minGBT, uint256 expireTimestamp) external;
    function sell(uint256 _amountGBT, uint256 _minETH, uint256 expireTimestamp) external;
    function BASE_TOKEN() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function gumbar() external view returns (address);
    function initial_totalSupply() external view returns (uint256);
    function reserveGBT() external view returns (uint256);
    function borrowCredit(address user) external view returns (uint256);
    function debt(address user) external view returns (uint256);
    function lockedXGBT(address user) external view returns (uint256);
    function unlockableXGBT(address user) external view returns (uint256);
    function reserveVirtualBASE() external view returns (uint256);
    function reserveRealBASE() external view returns (uint256);
    function floorPrice() external view returns (uint256);
    function mustStayGBT(address user) external view returns (uint256);
}

interface IGumball {
    function approve(address to, uint256 tokenId) external;
    function swapForExact(uint256[] memory id) external;
    function swap(uint256 _amount) external;
    function redeem(uint256[] memory _id) external;
    function gumballs() external view returns (uint256[] memory arr);
    function totalSupply() external view returns (uint256);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

interface IGumbar {
    function GBTperXGBT() external view returns (uint256);
    function gumballsDeposited(address user) external view returns (uint256, uint256[] memory);
    function balanceOfNFT(address user) external view returns (uint256, uint256[] memory);
    function getRewardForDuration(address _rewardsToken) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract Multicall {

    address factory;

    struct Response {
        address bondingCurve;
        address gumbar;
        uint256 index;
        uint256 gumbarTotalSupply;
        uint256 gbtPerXGBT;
        uint256 currentPrice;
    }

    struct UserData {
        // General
        uint256 currentPrice;
        uint256 apr;
        uint256 ltv;
        // Base token
        address baseToken;
        string baseSymbol;
        string baseName;
        uint256 baseBal;
        // ERC20BondingCurve
        uint256 gbtBalanceOfUser;
        uint256 gbtTotalSupply;
        uint256 gbtInitialTotalSupply;
        uint256 gbtFloorPrice;
        // Gumbar
        uint256 mustStayGBT;
        uint256[] stakedGumballs;
        uint256[] unstakedGumballs;
        // Available borrow
        uint256 borrowCredit;
        uint256 debt;
        uint256 lockedXGBT;
        uint256 unlockableXGBT;
        // Reserve values
        uint256 virtualBase;
        uint256 reserveRealBase;
        uint256 reserveGBT;
    }

    constructor(
        address _factory
    ) {
        factory = _factory;
    }

    function call() external view returns (Response[] memory response) {

        Response[] memory r = new Response[](totalCollections());

        for (uint256 i = 0; i < totalCollections(); i++) {
            r[i].bondingCurve = IFactory(factory).tokensDeployed(i);
            r[i].gumbar = IBondingCurve(IFactory(factory).tokensDeployed(i)).gumbar();  //
            r[i].index = i;
            r[i].gumbarTotalSupply = IERC20(r[i].gumbar).totalSupply();
            r[i].gbtPerXGBT = IGumbar(r[i].gumbar).GBTperXGBT();
            r[i].currentPrice = IBondingCurve(r[i].bondingCurve).currentPrice();
        }

        return(r);
    }

    function userData(address user, address gbtAddressForCollection) external view returns (UserData memory userdata) {

        UserData memory u;

        (uint256 index, ) = findDeployment(gbtAddressForCollection);

        if (user == address(0x0000000000000000000000000000000000000000)) {
            IERC20 gbt = IERC20(IFactory(factory).tokensDeployed(index));
            IERC20 base = IERC20(IBondingCurve(IFactory(factory).tokensDeployed(index)).BASE_TOKEN());
            address gumbar = IBondingCurve(address(gbt)).gumbar();

            uint256 gbtPerEth = IBondingCurve(address(gbt)).reserveGBT() * 1e18 / (IBondingCurve(address(gbt)).reserveVirtualBASE() + IBondingCurve(address(gbt)).reserveRealBASE());
            u.apr = 100 * 365 * ((IGumbar(gumbar).getRewardForDuration(IBondingCurve(address(gbt)).BASE_TOKEN()) * gbtPerEth) + IGumbar(gumbar).getRewardForDuration(address(gbt)) /  (IGumbar(gumbar).totalSupply() * 7));

            u.currentPrice = IBondingCurve(address(gbt)).currentPrice();
            u.ltv = 0;
            u.baseToken = address(base);
            u.baseSymbol = ERC20(address(base)).symbol();
            u.baseName = ERC20(address(base)).name();
            u.baseBal = 0;

            u.gbtBalanceOfUser = 0;
            u.gbtTotalSupply = IERC20(IFactory(factory).tokensDeployed(index)).totalSupply();
            u.gbtInitialTotalSupply = IBondingCurve(IFactory(factory).tokensDeployed(index)).initial_totalSupply();
            u.gbtFloorPrice = IBondingCurve(IFactory(factory).tokensDeployed(index)).floorPrice();

            u.mustStayGBT = 0;
            
            u.borrowCredit = 0;
            u.debt = 0;

            u.virtualBase = IBondingCurve(address(gbt)).reserveVirtualBASE();
            u.reserveRealBase = IBondingCurve(address(gbt)).reserveRealBASE();
            u.reserveGBT = IBondingCurve(address(gbt)).reserveGBT();
        } else {
            IERC20 gbt = IERC20(IFactory(factory).tokensDeployed(index));
            IERC20 base = IERC20(IBondingCurve(IFactory(factory).tokensDeployed(index)).BASE_TOKEN());
            address gumbar = IBondingCurve(IFactory(factory).tokensDeployed(index)).gumbar();
            
            uint256 gbtPerEth = IBondingCurve(address(gbt)).reserveGBT() * 1e18 / (IBondingCurve(address(gbt)).reserveVirtualBASE() + IBondingCurve(address(gbt)).reserveRealBASE());
            u.apr = 100 * 365 * ((IGumbar(gumbar).getRewardForDuration(IBondingCurve(address(gbt)).BASE_TOKEN()) * gbtPerEth) + IGumbar(gumbar).getRewardForDuration(address(gbt)) /  (IGumbar(gumbar).totalSupply() * 7));

            u.currentPrice = IBondingCurve(address(gbt)).currentPrice();
            u.ltv = 100 * IBondingCurve(address(gbt)).debt(user) * gbtPerEth / (IGumbar(address(gumbar)).balanceOf(user) * 1e18);

            u.baseToken = address(base);
            u.baseSymbol = ERC20(address(base)).symbol();
            u.baseName = ERC20(address(base)).name();
            u.baseBal = base.balanceOf(user);

            u.gbtBalanceOfUser = IERC20(IFactory(factory).tokensDeployed(index)).balanceOf(user);
            u.gbtTotalSupply = IERC20(IFactory(factory).tokensDeployed(index)).totalSupply();
            u.gbtInitialTotalSupply = IBondingCurve(IFactory(factory).tokensDeployed(index)).initial_totalSupply();
            u.gbtFloorPrice = IBondingCurve(IFactory(factory).tokensDeployed(index)).floorPrice();

            u.mustStayGBT = IBondingCurve(address(gbt)).mustStayGBT(user);

            (uint256 num, uint256[] memory arr) = IGumbar(address(gumbar)).balanceOfNFT(user);

            if (num == 0) {
                // do nothing
            } else {
                u.stakedGumballs = arr;
            }

            uint256 userBal = IERC721(IFactory(factory).gumballsDeployed(index)).balanceOf(user);
            uint256[] memory tokenIds = new uint256[](userBal);

            if (userBal == 0) {
                uint256[] memory empty;
                u.unstakedGumballs = empty;
            } else {
                for (uint256 i = 0; i < userBal; i++) {
                tokenIds[i] = IGumball(IFactory(factory).gumballsDeployed(index)).tokenOfOwnerByIndex(user, i);
            }
                u.unstakedGumballs = tokenIds;
            }
            
            u.borrowCredit = IBondingCurve(address(gbt)).borrowCredit(user);
            u.debt = IBondingCurve(address(gbt)).debt(user);

            u.virtualBase = IBondingCurve(address(gbt)).reserveVirtualBASE();
            u.reserveRealBase = IBondingCurve(address(gbt)).reserveRealBASE();
            u.reserveGBT = IBondingCurve(address(gbt)).reserveGBT();
        }

        return u;
    }

    function totalCollections() public view returns (uint256) {
        return IFactory(factory).totalDeployed();
    }

    function findDeployment(address toFind) public view returns (uint256 _index, bytes14 _type) {

        bool found = false;

        for(uint256 i = 0; i < IFactory(factory).totalDeployed(); i++) {
            
            if (IFactory(factory).tokensDeployed(i) == toFind) {
                found = true;
                return (i, bytes14('token'));
            } else if (IFactory(factory).gumballsDeployed(i) == toFind) {
                found = true;
                return (i, bytes14('gumball'));
            }
        }

        if (!found) {
            revert ('Address not found!');
        }
    }
}