pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../WBep20.sol";
import "../WLToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/WEL.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (WLToken[] memory);
    function claimWel(address) external;
    function venusAccrued(address) external view returns (uint);
}

contract WelLens {
    struct WLTokenMetadata {
        address wlToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint wlTokenDecimals;
        uint underlyingDecimals;
    }

    function wlTokenMetadata(WLToken wlToken) public returns (WLTokenMetadata memory) {
        uint exchangeRateCurrent = wlToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(wlToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(wlToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(wlToken.symbol(), "wlBNB")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            WBep20 aBep20 = WBep20(address(wlToken));
            underlyingAssetAddress = aBep20.underlying();
            underlyingDecimals = EIP20Interface(aBep20.underlying()).decimals();
        }

        return WLTokenMetadata({
            wlToken: address(wlToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: wlToken.supplyRatePerBlock(),
            borrowRatePerBlock: wlToken.borrowRatePerBlock(),
            reserveFactorMantissa: wlToken.reserveFactorMantissa(),
            totalBorrows: wlToken.totalBorrows(),
            totalReserves: wlToken.totalReserves(),
            totalSupply: wlToken.totalSupply(),
            totalCash: wlToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            wlTokenDecimals: wlToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }

    function wlTokenMetadataAll(WLToken[] calldata wlTokens) external returns (WLTokenMetadata[] memory) {
        uint wlTokenCount = wlTokens.length;
        WLTokenMetadata[] memory res = new WLTokenMetadata[](wlTokenCount);
        for (uint i = 0; i < wlTokenCount; i++) {
            res[i] = wlTokenMetadata(wlTokens[i]);
        }
        return res;
    }

    struct WLTokenBalances {
        address wlToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function wlTokenBalances(WLToken wlToken, address payable account) public returns (WLTokenBalances memory) {
        uint balanceOf = wlToken.balanceOf(account);
        uint borrowBalanceCurrent = wlToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = wlToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(wlToken.symbol(), "wlBNB")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            WBep20 aBep20 = WBep20(address(wlToken));
            EIP20Interface underlying = EIP20Interface(aBep20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(wlToken));
        }

        return WLTokenBalances({
            wlToken: address(wlToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function wlTokenBalancesAll(WLToken[] calldata wlTokens, address payable account) external returns (WLTokenBalances[] memory) {
        uint wlTokenCount = wlTokens.length;
        WLTokenBalances[] memory res = new WLTokenBalances[](wlTokenCount);
        for (uint i = 0; i < wlTokenCount; i++) {
            res[i] = wlTokenBalances(wlTokens[i], account);
        }
        return res;
    }

    struct WLTokenUnderlyingPrice {
        address wlToken;
        uint underlyingPrice;
    }

    function wlTokenUnderlyingPrice(WLToken wlToken) public view returns (WLTokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(wlToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return WLTokenUnderlyingPrice({
            wlToken: address(wlToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(wlToken)
        });
    }

    function wlTokenUnderlyingPriceAll(WLToken[] calldata wlTokens) external view returns (WLTokenUnderlyingPrice[] memory) {
        uint wlTokenCount = wlTokens.length;
        WLTokenUnderlyingPrice[] memory res = new WLTokenUnderlyingPrice[](wlTokenCount);
        for (uint i = 0; i < wlTokenCount; i++) {
            res[i] = wlTokenUnderlyingPrice(wlTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        WLToken[] markets;
        uint liquidity;
        uint shortfall;
    }

    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public view returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0, "account liquidity error");

        return AccountLimits({
            markets: comptroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct GovReceipt {
        uint proposalId;
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    function getGovReceipts(GovernorAlpha governor, address voter, uint[] memory proposalIds) public view returns (GovReceipt[] memory) {
        uint proposalCount = proposalIds.length;
        GovReceipt[] memory res = new GovReceipt[](proposalCount);
        for (uint i = 0; i < proposalCount; i++) {
            GovernorAlpha.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovProposal {
        uint proposalId;
        address proposer;
        uint eta;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        bool canceled;
        bool executed;
    }

    function setProposal(GovProposal memory res, GovernorAlpha governor, uint proposalId) internal view {
        (
            ,
            address proposer,
            uint eta,
            uint startBlock,
            uint endBlock,
            uint forVotes,
            uint againstVotes,
            bool canceled,
            bool executed
        ) = governor.proposals(proposalId);
        res.proposalId = proposalId;
        res.proposer = proposer;
        res.eta = eta;
        res.startBlock = startBlock;
        res.endBlock = endBlock;
        res.forVotes = forVotes;
        res.againstVotes = againstVotes;
        res.canceled = canceled;
        res.executed = executed;
    }

    function getGovProposals(GovernorAlpha governor, uint[] calldata proposalIds) external view returns (GovProposal[] memory) {
        GovProposal[] memory res = new GovProposal[](proposalIds.length);
        for (uint i = 0; i < proposalIds.length; i++) {
            (
                address[] memory targets,
                uint[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas
            ) = governor.getActions(proposalIds[i]);
            res[i] = GovProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                canceled: false,
                executed: false
            });
            setProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct WelBalanceMetadata {
        uint balance;
        uint votes;
        address delegate;
    }

    function getWelBalanceMetadata(WEL wel, address account) external view returns (WelBalanceMetadata memory) {
        return WelBalanceMetadata({
            balance: wel.balanceOf(account),
            votes: uint256(wel.getCurrentVotes(account)),
            delegate: wel.delegates(account)
        });
    }

    struct WelBalanceMetadataExt {
        uint balance;
        uint votes;
        address delegate;
        uint allocated;
    }

    function getWelBalanceMetadataExt(WEL wel, ComptrollerLensInterface comptroller, address account) external returns (WelBalanceMetadataExt memory) {
        uint balance = wel.balanceOf(account);
        comptroller.claimWel(account);
        uint newBalance = wel.balanceOf(account);
        uint accrued = comptroller.venusAccrued(account);
        uint total = add(accrued, newBalance, "sum wel total");
        uint allocated = sub(total, balance, "sub allocated");

        return WelBalanceMetadataExt({
            balance: balance,
            votes: uint256(wel.getCurrentVotes(account)),
            delegate: wel.delegates(account),
            allocated: allocated
        });
    }

    struct WelVotes {
        uint blockNumber;
        uint votes;
    }

    function getWelVotes(WEL wel, address account, uint32[] calldata blockNumbers) external view returns (WelVotes[] memory) {
        WelVotes[] memory res = new WelVotes[](blockNumbers.length);
        for (uint i = 0; i < blockNumbers.length; i++) {
            res[i] = WelVotes({
                blockNumber: uint256(blockNumbers[i]),
                votes: uint256(wel.getPriorVotes(account, blockNumbers[i]))
            });
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }
}
