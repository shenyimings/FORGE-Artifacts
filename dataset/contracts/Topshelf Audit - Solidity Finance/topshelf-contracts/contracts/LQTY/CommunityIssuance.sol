// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "../Interfaces/ICommunityIssuance.sol";
import "../Interfaces/ILQTYTreasury.sol";
import "../Dependencies/BaseMath.sol";
import "../Dependencies/LiquityMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/SafeMath.sol";


contract CommunityIssuance is ICommunityIssuance, Ownable, BaseMath {
    using SafeMath for uint;

    // --- Data ---

    string constant public NAME = "CommunityIssuance";

    uint constant public SECONDS_IN_ONE_MINUTE = 60;

   /* The issuance factor F determines the curvature of the issuance curve.
    *
    * Minutes in one year: 60*24*365 = 525600
    *
    * For 50% of remaining tokens issued each year, with minutes as time units, we have:
    *
    * F ** 525600 = 0.5
    *
    * Re-arranging:
    *
    * 525600 * ln(F) = ln(0.5)
    * F = 0.5 ** (1/525600)
    * F = 0.999998681227695000
    * F = 999998681227695000
    */
    uint public immutable ISSUANCE_FACTOR;
    /*
    * The community LQTY supply cap is the starting balance of the Community Issuance contract.
    * It should be minted to this contract by LQTYToken, when the token is deployed.
    */
    uint public override immutable LQTYSupplyCap;

    IERC20 public lqtyToken;
    address public lqtyTreasury;

    address public stabilityPoolAddress;

    uint public totalLQTYIssued;
    uint public issuanceStartTime;

    bool public isPaused;
    address public override shutdownAdmin;

    // --- Events ---

    event LQTYTokenAddressSet(address _lqtyTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalLQTYIssuedUpdated(uint _totalLQTYIssued);

    // --- Functions ---

    constructor(uint _supplyCap, uint _issuanceFactor, uint _issuanceDelay) public {
        LQTYSupplyCap = _supplyCap;
        ISSUANCE_FACTOR = _issuanceFactor;
        issuanceStartTime = _issuanceDelay;
    }

    function setAddresses
    (
        address _lqtyTokenAddress,
        address _stabilityPoolAddress,
        address _lqtyTreasuryAddress,
        address _shutdownAdminAddress
    )
        external
        onlyOwner
        override
    {
        lqtyToken = IERC20(_lqtyTokenAddress);
        stabilityPoolAddress = _stabilityPoolAddress;
        lqtyTreasury = _lqtyTreasuryAddress;
        shutdownAdmin = _shutdownAdminAddress;
        issuanceStartTime = ILQTYTreasury(_lqtyTreasuryAddress).issuanceStartTime().add(issuanceStartTime);

        require(lqtyToken.allowance(_lqtyTreasuryAddress, address(this)) >= LQTYSupplyCap);

        emit LQTYTokenAddressSet(_lqtyTokenAddress);
        emit StabilityPoolAddressSet(_stabilityPoolAddress);

        _renounceOwnership();
    }

    function setStabilityPool(address _stabilityPoolAddress) external {
        // in a case where the receiver is not a smart contract, we must be able to redirect
        require(msg.sender == stabilityPoolAddress);
        stabilityPoolAddress = _stabilityPoolAddress;
    }

    function setPaused(bool _isPaused) external override {
        require(msg.sender == shutdownAdmin);
        isPaused = _isPaused;
    }

    function issueLQTY() external override returns (uint) {
        _requireCallerIsStabilityPool();

        uint latestTotalLQTYIssued = LQTYSupplyCap.mul(_getCumulativeIssuanceFraction()).div(DECIMAL_PRECISION);
        uint issuance = latestTotalLQTYIssued.sub(totalLQTYIssued);

        totalLQTYIssued = latestTotalLQTYIssued;
        emit TotalLQTYIssuedUpdated(latestTotalLQTYIssued);

        // when the system is paused we still advance the issued amount, but always return 0
        // this way we avoid a sudden supply shock if we later unpause
        if (isPaused) return 0;

        return issuance;
    }

    /* Gets 1-f^t    where: f < 1

    f: issuance factor that determines the shape of the curve
    t:  time passed since last LQTY issuance event  */
    function _getCumulativeIssuanceFraction() internal view returns (uint) {
        if (block.timestamp < issuanceStartTime) return 0;

        // Get the time passed since deployment
        uint timePassedInMinutes = block.timestamp.sub(issuanceStartTime).div(SECONDS_IN_ONE_MINUTE);

        // f^t
        uint power = LiquityMath._decPow(ISSUANCE_FACTOR, timePassedInMinutes);

        //  (1 - f^t)
        uint cumulativeIssuanceFraction = (uint(DECIMAL_PRECISION).sub(power));
        assert(cumulativeIssuanceFraction <= DECIMAL_PRECISION); // must be in range [0,1]

        return cumulativeIssuanceFraction;
    }

    function sendLQTY(address _account, uint _LQTYamount) external override {
        _requireCallerIsStabilityPool();

        lqtyToken.transferFrom(lqtyTreasury, _account, _LQTYamount);
    }

    // --- 'require' functions ---

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "CommunityIssuance: caller is not SP");
    }
}
