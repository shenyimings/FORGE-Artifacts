// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "./interfaces/IProtocolFeePool.sol";
import "./interfaces/IMasterDeployer.sol";
import "./interfaces/IWETH.sol";
import "./libraries/FullMath.sol";
import "./interfaces/IProtocolRevenueShare.sol";


/**
 *
 * 판게아스왑 프로토콜 정산
 *
 * 2 단계로 나뉘어 호출됩니다. 주기적으로 풀에서 수수료 토큰들을 수취한 후,
 * revenueToken으로 일괄적으로 스왑하여, GrowthFund와 DaoFund로 분배합니다.
 *
 * 1. 각 풀 별 수수료 수취
 *
 *    ````solidity
 *    function collectByPage(uint256 start, uint256 limit) external;
 *    ````
 *
 *    * masterDeployer에 등록된 판게아스왑의 모든 풀들을 순회하며 호출
 *    * `collectFrom(pool)`을 호출하여 protocol 수수료 수취
 *    * 사전에 masterDeployer에서 protocolFeeTo를 변경
 *
 * 2. revenueToken으로 스왑 후 GrowthFund와 DaoFund로 분배
 *
 *    ````solidity
 *    function share(address feeToken, uint256 minimumOutput, address payable broker, bytes calldata data) external;
 *    ````
 *
 *    `growthFund`에 할당될 비율
 *     [1] 풀 별 growthFundRate가 지정되어 있는 경우에는 쓰고,
 *     [2] 아닌 경우에는 팩토리 별 growthFundRate를 사용
 *
 * ------------------------------------------------------------------------------------
 *
 * Growth Fund란?
 *
 * 판게아 스왑의 성장을 위해 사용하는 목적의 자금으로,
 * 주요 용처는 판게아 스왑의 TVL, Trading Volume을 만들어 줄 수 있는 파트너 프로토콜과의 협업을 위한 자금,
 * 판게아 스왑의 기능 개선 등을 시행할 수 있는 외부 Contributor에 대한 Grant 등으로 사용
 *
 *
 */
/// @notice 판게아스왑 프로토콜 수수료 분배를 담당하는 컨트랙트
contract ProtocolRevenueShare
    is IProtocolRevenueShare, AccessControlUpgradeable, Multicall {
    using SafeERC20 for IERC20;

    // @notice swapAndShare / collectByPage(uint256 start, uint256 limit)
    bytes32 public constant OP_ROLE = keccak256(abi.encode("OP"));
    bytes32 public constant MANAGER_ROLE = keccak256(abi.encode("MANAGER"));
    uint256 private constant BIPS = 10000;

    // @notice Pangeaswap MasterDeployer contracts
    address public masterDeployer;

    // @notice 모든 수익은 revenueToken(usdt)로 바뀌어 제공
    address public revenueToken;

    // @notice 정산 시 최소 revenueToken 갯수
    uint256 public minimumRevenue;

    // @notice wrapped KLAY
    address public wklay;

    // @notice Growth Fund address
    address public growthFund;

    // @notice DAO Fund address
    address public daoFund;

    // @notice 풀 별 Growth Fund에 할당될 물량 비율 (unit: bips, 10^4)
    mapping(address => uint256) private _growthFundRate;

    // @notice Growth Fund에 할당될 물량 비율 존재 여부
    mapping(address => bool) private _setupGrowthFundRate;

    // @notice 팩토리 별 Growth Fund에 할당될 물량 비율 (uint: bips, 10^4)
    mapping(address => uint256) private _factoryGrowthFundRate;

    // @notice 팩토리 별 Growth Fund에 할당될 물량  비율 존재 여부
    mapping(address => bool) private _setupFactoryGrowthFundRate;

    // @notice Growth Fund 할당량 (BIPS가 곱해져 있음)
    mapping(address => uint256) private _allocatedGrowthFunds;

    // @notice Fee Token을 Revenue 토큰으로 바꿀 수 있는 중개인인지 여부 ( pangeaswap PoolRouter, Dex Aggregators...)
    mapping(address => bool) public isVerifiedBroker;

    address private cachedPool;

    address[] private _feeTokens;
    mapping(address => bool) private isFee;

    function initialize(
        address _masterDeployer,
        address _revenueToken,
        address _wklay
    ) external initializer {
        require(_masterDeployer != address(0), "ZERO_ADDRESS");
        require(_revenueToken != address(0), "ZERO_ADDRESS");
        require(_wklay != address(0), "ZERO_ADDRESS");

        masterDeployer = _masterDeployer;
        revenueToken = _revenueToken;
        wklay = _wklay;

        minimumRevenue = 1_000_000;

        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    // @notice receive klay
    receive() external payable {
    }

    //////////////////////////////////////////
    // MANAGER FUNCTION
    //////////////////////////////////////////
    // @notice set revenueToken, only manager can update
    function setRevenueToken(address _token) external onlyRole(MANAGER_ROLE) {
        require(_token != address(0), "NOT_ZERO");
        revenueToken = _token;

        emit SetRevenueToken(_token);
    }

    // @notice set growthFund, only manager can update
    function setGrowthFund(address _fund) external onlyRole(MANAGER_ROLE) {
        require(_fund != address(0), "NOT_ZERO");
        growthFund = _fund;

        emit SetGrowthFund(_fund);
    }

    // @notice set daoFund, only manager can update
    function setDaoFund(address _fund) external onlyRole(MANAGER_ROLE) {
        require(_fund != address(0), "NOT_ZERO");
        daoFund = _fund;

        emit SetDaoFund(_fund);
    }

    // @notice set MinimumRevenue, only manager can update
    function setMinimumRevenue(uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(amount > 0, "NOT_ZERO");
        minimumRevenue = amount;

        emit SetMinimumRevenue(amount);
    }

    // @notice 풀 별 프로토콜 수익 중 growth fund에 할당할 비율
    function setGrowthFundRate(address _pool, uint256 _rate) external onlyRole(MANAGER_ROLE) {
        require(_pool != address(0), "NOT_ZERO");
        require(_rate <= BIPS, "TOO_BIG");

        _growthFundRate[_pool] = _rate;
        _setupGrowthFundRate[_pool] = true;

        emit SetGrowthFundRate(_pool, _rate);
    }

    // @notice 팩토리 별 프로토콜 수익 중 growth fund에 할당할 기본 비율, 풀 별 growthFundRate가 미지정인 경우 이용
    function setFactoryGrowthFundRate(address _factory, uint256 _rate) external onlyRole(MANAGER_ROLE) {
        require(_factory != address(0), "NOT_ZERO");
        require(_rate <= BIPS, "TOO_BIG");

        _factoryGrowthFundRate[_factory] = _rate;
        _setupFactoryGrowthFundRate[_factory] = true;

        emit SetFactoryGrowthFundRate(_factory, _rate);
    }

    // @notice Fee 토큰을 Revenue 토큰으로 스왑을 중개할 수 있는 브로커로 허용할 것인지 여부
    function verifyBroker(address broker, bool isVerified) external onlyRole(MANAGER_ROLE) {
        require(broker != address(0), "NOT_ZERO");
        isVerifiedBroker[broker] = isVerified;

        emit VerifyBroker(broker, isVerified);
    }

    // @notice Broker에게 feeToken에 대해 Approval을 미리 제공
    // @dev 특정 브로커의 경우에는 approve 획득 전에는 경로를 제공하지 않기 때문에 구성
    function setApproval(address broker, address feeToken, bool ok) external onlyRole(MANAGER_ROLE) {
        require(isVerifiedBroker[broker], "NOT_VERIFED");
        if (ok) {
            IERC20(feeToken).approve(broker, type(uint256).max);
        } else {
            IERC20(feeToken).approve(broker, 0);
        }
    }

    // @notice Growth Fund에 할애할 비중 계산
    function getGrowthFundRate(address _pool) public view returns (uint256 rate) {
        if (_setupGrowthFundRate[_pool]) {
            return _growthFundRate[_pool];
        } else {
            // @dev 풀 별 growth fund rate가 미지정되어 있으면, factory의 growth fund rate를 지정
            address factory = IMasterDeployer(masterDeployer).getFactoryAddress(_pool);
            require(_setupFactoryGrowthFundRate[factory], "NOT_SETUP");
            return _factoryGrowthFundRate[factory];
        }
    }

    /// @notice 특정 토큰에 대한 Revenue 비율 파악
    function allocateRevenue(address feeToken) external view returns (uint256 amount, uint256 growthFundShare, uint256 daoFundShare) {
        amount = IERC20(feeToken).balanceOf(address(this));
        growthFundShare = FullMath.mulDiv(amount, _allocatedGrowthFunds[feeToken], amount * BIPS);
        daoFundShare = amount - growthFundShare;
    }

    function totalFeeTokens() external view returns (uint256) {
        return _feeTokens.length;
    }

    function feeTokens(uint256 start, uint256 end) external view returns (address[] memory tokens){
        tokens = new address[](end - start);

        end = Math.min(end, _feeTokens.length);
        for (uint256 i = start; i< end; i++) {
            tokens[i]  = _feeTokens[i];
        }
    }

    /// @notice deployer에서 순회하며, 수수료 수취 호출
    function collectByPage(uint256 start, uint256 limit) external onlyRole(OP_ROLE) {
        IMasterDeployer deployer = IMasterDeployer(masterDeployer);

        uint256 end = Math.min(deployer.totalPoolsCount(), start + limit);
        if (start >= end) return;

        for (uint256 i = start; i < end; i++) {
            address pool = deployer.getPoolAddress(i);
            (uint128 rev0, uint128 rev1) = IProtocolFeePool(pool).getTokenProtocolFees();

            // @dev 프로토콜 수익이 존재하지 않은 경우 스킵
            if (rev0 == 0 && rev1 == 0) continue;

            cachedPool = pool;
            IProtocolFeePool(pool).collectProtocolFee();
        }

        cachedPool = address(0);
    }

    /// @notice 특정 풀에서 프로토콜 수익 모으기
    function collectFrom(address pool) external onlyRole(OP_ROLE) {
        cachedPool = pool;
        IProtocolFeePool(pool).collectProtocolFee();
        cachedPool = address(0);
    }

    // @notice 풀에서 발생한 수익을 스왑 후, Growth Fund와 Dao Fund로 분배
    // @param feeToken 프로토콜에서 발생한 수익 토큰
    // @param minimumOutput 스왑할 경우, 슬리피지를 고려한 output
    // @param broker feeToken을 revenueToken으로 전환을 수행하는 컨트랙트 ( pangeaswap pool Router, swap Scanner, 1inch, ...)
    // @param data broker 컨트랙트로의 콜백 데이터
    function share(
        address feeToken,
        uint256 minimumOutput,
        address payable broker,
        bytes calldata data
    ) external onlyRole(OP_ROLE) {
        // 1. collect된 protocol revenue를 가져오기
        uint256 amount = IERC20(feeToken).balanceOf(address(this));

        // 2. revenueToken으로 전환 (feeToken == revenueToken인 경우 스킵)
        uint256 output = swapToRevenueToken(feeToken, amount, minimumOutput, broker, data);

        // 3. Fund 별 지분 분리
        (uint256 growthFundShare, uint256 daoFundShare) = settleFundShare(feeToken, amount, output);

        // 4. 각 펀드로 자산 전송
        IERC20 revenue = IERC20(revenueToken);
        if (growthFundShare > 0) revenue.safeTransfer(growthFund, growthFundShare);
        if (daoFundShare > 0) revenue.safeTransfer(daoFund, daoFundShare);

        // 5. 이벤트 발행
        emit Share(feeToken, address(revenue), amount, output, growthFundShare, daoFundShare);
    }

    // @notice fund 할당량 나누기
    function settleFundShare(address feeToken, uint256 total, uint256 amount) internal returns (uint256 growthFundShare, uint256 daoFundShare) {
        growthFundShare = FullMath.mulDiv(amount, _allocatedGrowthFunds[feeToken], total * BIPS);
        _allocatedGrowthFunds[feeToken] = 0;
        daoFundShare = amount > growthFundShare ? amount - growthFundShare : 0;
    }

    function swapToRevenueToken(
        address token,
        uint256 amount,
        uint256 minimumOutput,
        address payable broker,
        bytes calldata data
    ) internal returns (uint256 output) {
        IWETH weth = IWETH(wklay);
        IERC20 revenue = IERC20(revenueToken);

        // @dev revenue 토큰과 동일한 경우에는 스왑 스킵
        if (token == address(revenue)) return amount;

        uint256 prevAmount = revenue.balanceOf(address(this));

        require(isVerifiedBroker[broker], "NOT_VERIFIED_BROKER");
        {
            bool success;
            if (address(weth) == token) {
                // unwrap first
                weth.withdraw(amount);
                (success, ) = broker.call{value: amount}(data);
            } else {
                // approve first
                IERC20(token).approve(broker, amount);
                (success, ) = broker.call(data);
                IERC20(token).approve(broker, 0);
            }
            require(success, "BROKER_FAIL");
        }

        output = revenue.balanceOf(address(this)) - prevAmount;
        require(output >= minimumOutput, "SLIPPAGE");
        require(output >= minimumRevenue, "MINIMUM REVENUE");
    }


    /// @notice Callback 함수 (Pool에서 호출)
    function collectFeeCallback(address[] memory tokens, uint256[] memory amounts) external {
        address _pool = _msgSender();
        require(cachedPool == _pool, "NOT ALLOWED");
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            // @dev skip if amount == 0
            if (amount == 0) continue;

            // @dev feeToken 등록
            if (!isFee[token]) {
                _feeTokens.push(token);
                isFee[token] = true;
            }

            // @dev growthFund Rate 적용하여 할당
            _allocatedGrowthFunds[token] += amount * getGrowthFundRate(_pool);

            emit Collect(_pool, token, amount);
        }
    }
}
