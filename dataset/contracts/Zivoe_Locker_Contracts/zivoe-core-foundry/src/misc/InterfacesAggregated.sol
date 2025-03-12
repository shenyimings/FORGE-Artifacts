// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// ----------
//    EIPs
// ----------

interface IERC20Mintable is IERC20, IERC20Metadata {
    function mint(address account, uint256 amount) external;
    function isMinter(address account) external view returns (bool);
}

// interface IERC721 {
//     function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;
//     function approve(address to, uint256 tokenId) external;
// }

// interface IERC1155 { 
//     function setApprovalForAll(address operator, bool approved) external;
//     function safeBatchTransferFrom(
//         address from,
//         address to,
//         uint256[] calldata ids,
//         uint256[] calldata amounts,
//         bytes calldata data
//     ) external;
// }




// -----------
//    Zivoe
// -----------

interface GenericData {
    function GBL() external returns (address);
    function owner() external returns (address);
}

interface ILocker {
    function pushToLocker(address asset, uint256 amount) external;
    function pullFromLocker(address asset) external;
    function pullFromLockerPartial(address asset, uint256 amount) external;
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external;
    function pullFromLockerMulti(address[] calldata assets) external;
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external;
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;
    function pushToLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external;
    function pullFromLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external;
    function pushToLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function pullFromLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function canPush() external view returns (bool);
    function canPull() external view returns (bool);
    function canPullPartial() external view returns (bool);
    function canPushMulti() external view returns (bool);
    function canPullMulti() external view returns (bool);
    function canPullMultiPartial() external view returns (bool);
    function canPushERC721() external view returns (bool);
    function canPullERC721() external view returns (bool);
    function canPushMultiERC721() external view returns (bool);
    function canPullMultiERC721() external view returns (bool);
    function canPushERC1155() external view returns (bool);
    function canPullERC1155() external view returns (bool);
}

interface IZivoeDAO is GenericData {
    
}

interface IZivoeGovernor {
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function quorum(uint256 blockNumber) external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function COUNTING_MODE() external pure returns (string memory);
    function quorumNumerator() external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function timelock() external view returns (address);
    function token() external view returns (address); // IVotes?
}

interface IZivoeGlobals {
    function DAO() external view returns (address);
    function ITO() external view returns (address);
    function stJTT() external view returns (address);
    function stSTT() external view returns (address);
    function stZVE() external view returns (address);
    function vestZVE() external view returns (address);
    function YDL() external view returns (address);
    function zJTT() external view returns (address);
    function zSTT() external view returns (address);
    function ZVE() external view returns (address);
    function ZVL() external view returns (address);
    function ZVT() external view returns (address);
    function GOV() external view returns (address);
    function TLC() external view returns (address);
    function isKeeper(address) external view returns (bool);
    function isLocker(address) external view returns (bool);
    function stablecoinWhitelist(address) external view returns (bool);
    function defaults() external view returns (uint256);
    function increaseDefaults(uint256) external;
    function decreaseDefaults(uint256) external;
    function standardize(uint256, address) external view returns (uint256);
    function adjustedSupplies() external view returns (uint256, uint256);
}

interface IZivoeITO is GenericData {
    function claimAirdrop(address) external returns (uint256 _zJTT, uint256 _zSTT, uint256 _ZVE);
    function start() external view returns (uint256);
    function end() external view returns (uint256);
    function stables(uint256) external view returns (address);
    function stablecoinWhitelist(address) external view returns (bool);
}

interface ITimelockController is GenericData {
    function getMinDelay() external view returns (uint256);
    function hasRole(bytes32, address) external view returns (bool);
    function getRoleAdmin(bytes32) external view returns (bytes32);
}

struct Reward {
    uint256 rewardsDuration;        /// @dev How long rewards take to vest, e.g. 30 days.
    uint256 periodFinish;           /// @dev When current rewards will finish vesting.
    uint256 rewardRate;             /// @dev Rewards emitted per second.
    uint256 lastUpdateTime;         /// @dev Last time this data struct was updated.
    uint256 rewardPerTokenStored;   /// @dev Last snapshot of rewardPerToken taken.
}

interface IZivoeRewards is GenericData {
    function depositReward(address _rewardsToken, uint256 reward) external;
    function rewardTokens() external view returns (address[] memory);
    function rewardData(address) external view returns (Reward memory);
    function stakingToken() external view returns (address);
    function viewRewards(address, address) external view returns (uint256);
    function viewAccountRewardPerTokenPaid(address, address) external view returns (uint256);
    function earned(address account, address rewardsToken) external returns (uint256 amount);
}

interface IZivoeRewardsVesting is GenericData, IZivoeRewards {

}

interface IZivoeToken is IERC20, IERC20Metadata, GenericData {

}

interface IZivoeTranches is ILocker, GenericData {
    function maxTrancheRatioBIPS() external view returns (uint256);
    function minZVEPerJTTMint() external view returns (uint256);
    function maxZVEPerJTTMint() external view returns (uint256);
    function lowerRatioIncentiveBIPS() external view returns (uint256);
    function upperRatioIncentiveBIPS() external view returns (uint256);
    function unlock() external;
    function tranchesUnlocked() external view returns (bool);
    function GBL() external view returns (address);
}
interface IZivoeTrancheToken is IERC20, IERC20Metadata, GenericData, IERC20Mintable {

}

interface IZivoeYDL is GenericData {
    function distributeYield() external;
    function unlock() external;
    function unlocked() external view returns (bool);
    function distributedAsset() external view returns (address);
    function emaSTT() external view returns (uint256);
    function emaJTT() external view returns (uint256);
    function distributionCounter() external view returns (uint256);
    function lastDistribution() external view returns (uint256);
    function targetAPYBIPS() external view returns (uint256);
    function targetRatioBIPS() external view returns (uint256);
    function protocolEarningsRateBIPS() external view returns (uint256);
    function daysBetweenDistributions() external view returns (uint256);
    function retrospectiveDistributions() external view returns (uint256);
    function earningsTrancheuse() external view returns (uint256[] memory, uint256, uint256, uint256[] memory);
}


// ---------------
//    Protocols
// ---------------

struct PoolInfo {
    address lptoken;
    address token;
    address gauge;
    address crvRewards;
    address stash;
    bool shutdown;
}

struct TokenInfo {
    address token;
    address rewardAddress;
    uint256 lastActiveTime;
}

interface ICVX_Booster {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
    function depositAll(uint256 _pid, bool _stake) external returns(bool);
    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);
}

interface IConvexRewards {
    function getReward() external returns (bool);
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns (bool);
    function withdrawAllAndUnwrap(bool _claim) external;
    function balanceOf(address _account) external view returns(uint256);
}

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

interface ICRVDeployer {
    function deploy_metapool(
        address _bp, 
        string calldata _name, 
        string calldata _symbol, 
        address _coin, 
        uint256 _A, 
        uint256 _fee
    ) external returns (address);
}

interface ICRVMetaPool {
    function add_liquidity(uint256[2] memory amounts_in, uint256 min_mint_amount) external payable returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function balances(uint256 i) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    function base_pool() external view returns(address);
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts_out) external returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint256 min_amount) external;
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
}

interface ICRVPlainPoolFBP {
    function add_liquidity(uint256[2] memory amounts_in, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(uint256[3] memory amounts_in, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(uint256[4] memory amounts_in, uint256 min_mint_amount) external returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function balances(uint256 i) external view returns (uint256);
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts_out) external returns (uint256[2] memory);
    function remove_liquidity(uint256 amount, uint256[3] memory min_amounts_out) external returns (uint256[3] memory);
    function remove_liquidity(uint256 amount, uint256[4] memory min_amounts_out) external returns (uint256[4] memory);
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint256 min_amount) external;
    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function exchange(int128 indexTokenIn, int128 indexTokenOut, uint256 amountIn, uint256 minToReceive) external returns (uint256 amountReceived);
}

interface ICRVPlainPool3CRV {
    function add_liquidity(uint256[3] memory amounts_in, uint256 min_mint_amount) external;
    function coins(uint256 i) external view returns (address);
    function remove_liquidity(uint256 amount, uint256[3] memory min_amounts_out) external;
}

interface ICRV_PP_128_NP {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface ICRV_MP_256 {
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
}

interface ISushiRouter {
     function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface ISushiFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Router01 {
     function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

struct SwapDescription {
    IERC20 srcToken;
    IERC20 dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
    bytes permit;
}

interface IAggregationExecutor {
    function callBytes(address msgSender, bytes calldata data) external payable;  // 0x2636f7f8
}

interface IAggregationRouterV4 {
    function swap(IAggregationExecutor caller, SwapDescription memory desc, bytes calldata data) external payable;
}

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}
