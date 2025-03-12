pragma solidity 0.5.16;

import { Ownable } from "@openzeppelin/contracts/ownership/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IRegistry } from "./interfaces/IRegistry.sol";
import { ICToken, ICErc20, ICEther } from "./interfaces/CTokenInterfaces.sol";
import { IBToken } from "./interfaces/IBToken.sol";
import {
    IAvatar,
    IAvatarCErc20,
    IAvatarCEther,
    ICushion,
    ICushionCEther,
    ICushionCErc20
} from "./interfaces/IAvatar.sol";
import { IComptroller } from "./interfaces/IComptroller.sol";
import { IBComptroller } from "./interfaces/IBComptroller.sol";

import { Exponential } from "./lib/Exponential.sol";

/**
 * @title Pool contract to manage the pool of member's fund
 */
contract Pool is Exponential, Ownable {
    using SafeERC20 for IERC20;
    address internal constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IComptroller public comptroller;
    IBComptroller public bComptroller;
    IRegistry public registry;
    address public jar;
    address public cEther;
    address[] public members;
    // member share profit params
    uint public shareNumerator;
    uint public shareDenominator;
    // member => underlying => amount
    mapping(address => mapping(address => uint)) public balance;
    // member => underlying => amount
    mapping(address => mapping(address => uint)) public topupBalance;
    // avatar => TopupInfo
    mapping(address => TopupInfo) public topped;

    // bToken => threshold
    mapping(address => uint) public minSharingThreshold; // debt above this size will be shared
    uint public minTopupBps = 250; // 2.5%
    uint public holdingTime = 5 hours; // after 5 hours, someone else can topup instead
    uint public selectionDuration = 60 minutes;  // member selection duration for round robin, default 10 mins

    struct MemberTopupInfo {
        uint expire;        // after expire time, other member can topup. relevant only if small
        uint amountTopped;  // amount of underlying tokens toppedUp
        uint amountLiquidated; // how much was already liquidated
    }

    struct TopupInfo {
        mapping(address => MemberTopupInfo) memberInfo; // info per member
        uint debtToLiquidatePerMember; // total debt avail to liquidate
        address cToken;          // underlying debt cToken address
    }

    function getMemberTopupInfo(
        address user,
        address member
    )
        public
        view
        returns (
            uint expire,
            uint amountTopped,
            uint amountLiquidated
        )
    {
        address avatar = registry.avatarOf(user);
        MemberTopupInfo memory memberInfo = topped[avatar].memberInfo[member];
        expire = memberInfo.expire;
        amountTopped = memberInfo.amountTopped;
        amountLiquidated = memberInfo.amountLiquidated;
    }

    function getDebtTopupInfo(address user, address bTokenDebt) public /* view */ returns(uint minTopup, uint maxTopup, bool isSmall) {
        uint debt = IBToken(bTokenDebt).borrowBalanceCurrent(user);
        minTopup = mul_(debt, minTopupBps) / 10000;
        maxTopup = debt / members.length;
        isSmall = debt < minSharingThreshold[bTokenDebt];
    }

    function untop(address user, uint underlyingAmount) public onlyMember {
        _untop(msg.sender, user, underlyingAmount);
    }

    function _untopOnBehalf(address member, address user, uint underlyingAmount) internal {
        _untop(member, user, underlyingAmount);
    }

    function _untop(address member, address user, uint underlyingAmount) internal {
        require(underlyingAmount > 0, "Pool: amount-is-zero");
        address avatar = registry.avatarOf(user);
        TopupInfo storage info = topped[avatar];

        address bToken = bComptroller.c2b(info.cToken);

        MemberTopupInfo storage memberInfo = info.memberInfo[member];
        // cannot untop more than topped up amount
        require(memberInfo.amountTopped >= underlyingAmount, "Pool: amount-too-big");
        require(ICushion(avatar).remainingLiquidationAmount() == 0, "Pool: cannot-untop-in-liquidation");

        (uint minTopup,,) = getDebtTopupInfo(user, bToken);

        require(
            memberInfo.amountTopped == underlyingAmount ||
            sub_(memberInfo.amountTopped, underlyingAmount) >= minTopup,
            "Pool: invalid-amount"
        );

        if(ICushion(avatar).toppedUpAmount() > 0) ICushion(avatar).untop(underlyingAmount);
        address underlying = _getUnderlying(info.cToken);
        balance[member][underlying] = add_(balance[member][underlying], underlyingAmount);
        topupBalance[member][underlying] = sub_(topupBalance[member][underlying], underlyingAmount);

        memberInfo.amountTopped = 0;
        memberInfo.expire = 0;
    }

    function smallTopupWinner(address avatar) public view returns(address) {
        uint chosen = uint(keccak256(abi.encodePacked(avatar, now / selectionDuration))) % members.length;
        return members[chosen];
    }

    function topup(address user, address bToken, uint amount, bool resetApprove) external onlyMember {
        address avatar = registry.avatarOf(user);
        address cToken = bComptroller.b2c(bToken);
        (uint minTopup, uint maxTopup, bool small) = getDebtTopupInfo(user, bToken);

        address underlying = _getUnderlying(cToken);
        uint memberBalance = balance[msg.sender][underlying];

        require(memberBalance >= amount, "Pool: topup-insufficient-balance");
        require(ICushion(avatar).remainingLiquidationAmount() == 0, "Pool: cannot-topup-in-liquidation");

        TopupInfo storage info = topped[avatar];
        _untopOnMembers(user, avatar, cToken, small);

        MemberTopupInfo storage memberInfo = info.memberInfo[msg.sender];
        require(add_(amount, memberInfo.amountTopped) >= minTopup, "Pool: topup-amount-small");
        require(add_(amount, memberInfo.amountTopped) <= maxTopup, "Pool: topup-amount-big");

        // For first topup skip this check as `expire = 0`
        // From next topup, check for turn of msg.sender (new member)
        if(small && memberInfo.expire != 0 && memberInfo.expire <= now) {
            require(smallTopupWinner(avatar) == msg.sender, "Pool: topup-not-your-turn");
        }

        // topup is valid
        balance[msg.sender][underlying] = sub_(memberBalance, amount);
        topupBalance[msg.sender][underlying] = add_(topupBalance[msg.sender][underlying], amount);

        if(small && memberInfo.expire <= now) {
            memberInfo.expire = add_(now, holdingTime);
        }

        memberInfo.amountTopped = add_(memberInfo.amountTopped, amount);
        // in all the below, as sload will soon cost 2k gas, we use sstore without
        // checking if the value really changed
        memberInfo.amountLiquidated = 0;
        info.debtToLiquidatePerMember = 0;
        info.cToken = cToken;

        if(_isCEther(cToken)) {
            ICushionCEther(avatar).topup.value(amount)();
        } else {
            if(resetApprove) IERC20(underlying).safeApprove(avatar, 0);
            IERC20(underlying).safeApprove(avatar, amount);
            ICushionCErc20(avatar).topup(cToken, amount);
        }
    }

    // created this function to avoid stack too deep error
    function _untopOnMembers(address user, address avatar, address cToken, bool small) internal {
        uint realCushion = ICushion(avatar).toppedUpAmount();
        TopupInfo memory info = topped[avatar];
        for(uint i = 0 ; i < members.length ; i++) {
            address member = members[i];
            MemberTopupInfo memory memberInfo = topped[avatar].memberInfo[member];
            uint amount = memberInfo.amountTopped;
            if(amount > 0) {
                if(realCushion == 0) {
                    _untopOnBehalf(member, user, amount);
                    // now it is 0 topup
                    continue;
                }

                require(info.cToken == cToken, "Pool: cToken-miss-match");

                if(member == msg.sender) continue; // skil below check for me(member)
                if(! small) continue; // if big loan, share with it with other members
                // me(member) checking for other member's expire
                require(memberInfo.expire < now, "Pool: other-member-topped");
                _untopOnBehalf(member, user, amount);
            }
        }
    }

    event MemberDeposit(address indexed member, address underlying, uint amount);
    event MemberWithdraw(address indexed member, address underlying, uint amount);
    event MemberToppedUp(address indexed member, address avatar, address cToken, uint amount);
    event MemberUntopped(address indexed member, address avatar);
    event MemberBite(address indexed member, address avatar, address cTokenDebt, address cTokenCollateral, uint underlyingAmtToLiquidate);
    event ProfitParamsChanged(uint numerator, uint denominator);
    event MembersSet(address[] members);
    event SelectionDurationChanged(uint oldDuration, uint newDuration);
    event MinTopupBpsChanged(uint oldMinTopupBps, uint newMinTopupBps);
    event HoldingTimeChanged(uint oldHoldingTime, uint newHoldingTime);
    event MinSharingThresholdChanged(address indexed bToken, uint oldThreshold, uint newThreshold);

    modifier onlyMember() {
        require(_isMember(msg.sender), "Pool: not-member");
        _;
    }

    constructor(address _jar) public {
        jar = _jar;
    }

    // Added to avoid stack-too-deep-error
    // This also reduce the code size as modifier code is copied to function
    function _isMember(address member) internal view returns (bool isMember) {
        for(uint i = 0 ; i < members.length ; i++) {
            if(members[i] == member) {
                isMember = true;
                break;
            }
        }
    }

    function setRegistry(address _registry) external onlyOwner {
        require(address(registry) == address(0), "Pool: registry-already-set");
        registry = IRegistry(_registry);
        comptroller = IComptroller(registry.comptroller());
        bComptroller = IBComptroller(registry.bComptroller());
        cEther = registry.cEther();
    }

    function emergencyExecute(address target, bytes calldata data) external payable onlyOwner {
        (bool succ, bytes memory ret) = target.call.value(msg.value)(data);
        require(succ, string(ret));
    }

    /**
     * @dev Fallback function to receive ETH from Avatar
     */
    function() external payable {}

    function setMinTopupBps(uint newMinTopupBps) external onlyOwner {
        require(newMinTopupBps >= 0 && newMinTopupBps <= 10000, "Pool: incorrect-minTopupBps");
        uint oldMinTopupBps = minTopupBps;
        minTopupBps = newMinTopupBps;
        emit MinTopupBpsChanged(oldMinTopupBps, newMinTopupBps);
    }

    function setHoldingTime(uint newHoldingTime) external onlyOwner {
        require(newHoldingTime > 0, "Pool: incorrect-holdingTime");
        uint oldHoldingTime = holdingTime;
        holdingTime = newHoldingTime;
        emit HoldingTimeChanged(oldHoldingTime, newHoldingTime);
    }

    function setMinSharingThreshold(address bToken, uint newMinThreshold) external onlyOwner {
        require(newMinThreshold > 0, "Pool: incorrect-minThreshold");
        require(bComptroller.isBToken(bToken), "Pool: not-a-BToken");
        uint oldMinThreshold = minSharingThreshold[bToken];
        minSharingThreshold[bToken] = newMinThreshold;
        emit MinSharingThresholdChanged(bToken, oldMinThreshold, newMinThreshold);
    }

    function setProfitParams(uint numerator, uint denominator) external onlyOwner {
        require(numerator < denominator, "Pool: invalid-profit-params");
        shareNumerator = numerator;
        shareDenominator = denominator;
        emit ProfitParamsChanged(numerator, denominator);
    }

    function setSelectionDuration(uint newDuration) external onlyOwner {
        require(newDuration > 0, "Pool: selection-duration-is-zero");
        uint oldDuration = selectionDuration;
        selectionDuration = newDuration;
        emit SelectionDurationChanged(oldDuration, newDuration);
    }

    function setMembers(address[] calldata newMembersList) external onlyOwner {
        members = newMembersList;
        emit MembersSet(newMembersList);
    }

    function deposit() external payable onlyMember {
        balance[msg.sender][ETH_ADDR] = add_(balance[msg.sender][ETH_ADDR], msg.value);
        emit MemberDeposit(msg.sender, ETH_ADDR, msg.value);
    }

    function deposit(address underlying, uint amount) external onlyMember {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        balance[msg.sender][underlying] = add_(balance[msg.sender][underlying], amount);
        emit MemberDeposit(msg.sender, underlying, amount);
    }

    function withdraw(address underlying, uint amount) external {
        if(_isETH(underlying)) {
            balance[msg.sender][ETH_ADDR] = sub_(balance[msg.sender][ETH_ADDR], amount);
            msg.sender.transfer(amount);
        } else {
            balance[msg.sender][underlying] = sub_(balance[msg.sender][underlying], amount);
            IERC20(underlying).safeTransfer(msg.sender, amount);
        }
        emit MemberWithdraw(msg.sender, underlying, amount);
    }

    function liquidateBorrow(
        address borrower,
        address bTokenCollateral,
        address bTokenDebt,
        uint underlyingAmtToLiquidate
    )
        external onlyMember
    {
        address cTokenCollateral = bComptroller.b2c(bTokenCollateral);
        address cTokenDebt = bComptroller.b2c(bTokenDebt);
        address avatar = registry.avatarOf(borrower);
        TopupInfo storage info = topped[avatar];

        require(info.memberInfo[msg.sender].amountTopped > 0, "Pool: member-didnt-topup");
        uint debtToLiquidatePerMember = info.debtToLiquidatePerMember;

        if(debtToLiquidatePerMember == 0) {
            uint numMembers = 0;
            for(uint i = 0 ; i < members.length ; i++) {
                if(info.memberInfo[members[i]].amountTopped > 0) {
                    numMembers++;
                }
            }
            debtToLiquidatePerMember = ICushion(avatar).getMaxLiquidationAmount(cTokenDebt) / numMembers;
            info.debtToLiquidatePerMember = debtToLiquidatePerMember;
        }

        MemberTopupInfo memory memberInfo = info.memberInfo[msg.sender];

        require(memberInfo.amountTopped > 0, "Pool: member-didnt-topup");
        require(
            add_(memberInfo.amountLiquidated, underlyingAmtToLiquidate) <= debtToLiquidatePerMember,
            "Pool: amount-too-big"
        );

        uint amtToDeductFromTopup = mul_(underlyingAmtToLiquidate, memberInfo.amountTopped) / (
            sub_(debtToLiquidatePerMember, memberInfo.amountLiquidated)
        );

        uint amtToRepayOnCompound = sub_(underlyingAmtToLiquidate, amtToDeductFromTopup);

        address debtUnderlying = _getUnderlying(cTokenDebt);
        require(balance[msg.sender][debtUnderlying] >= amtToRepayOnCompound, "Pool: low-member-balance");

        if(! _isCEther(cTokenDebt)) {
            IERC20(debtUnderlying).safeApprove(avatar, amtToRepayOnCompound);
        }

        require(
            ICushion(avatar).liquidateBorrow.value(debtUnderlying == ETH_ADDR ?
                                                   amtToRepayOnCompound :
                                                   0)(underlyingAmtToLiquidate, amtToDeductFromTopup, cTokenCollateral) == 0,
            "Pool: liquidateBorrow-failed"
        );

        // substract payment from member balance
        balance[msg.sender][debtUnderlying] = sub_(balance[msg.sender][debtUnderlying],  amtToRepayOnCompound);

        // share siezed cTokens with `member` and `jar`
        _shareLiquidationProceeds(cTokenCollateral, msg.sender);

        info.memberInfo[msg.sender].amountLiquidated = add_(memberInfo.amountLiquidated, underlyingAmtToLiquidate);
        info.memberInfo[msg.sender].amountTopped = sub_(memberInfo.amountTopped, amtToDeductFromTopup);
        topupBalance[msg.sender][debtUnderlying] = sub_(topupBalance[msg.sender][debtUnderlying], amtToDeductFromTopup);
        if(IAvatar(avatar).toppedUpAmount() == 0) {
            //info.debtToLiquidatePerMember = 0; // this indicates the liquidation ended
            delete topped[avatar]; // this will reset debtToLiquidatePerMember
        }
        emit MemberBite(msg.sender, avatar, cTokenDebt, cTokenCollateral, underlyingAmtToLiquidate);
    }

    function _shareLiquidationProceeds(address cTokenCollateral, address member) internal {
        uint seizedTokens = IERC20(cTokenCollateral).balanceOf(address(this));
        uint memberShare = div_(mul_(seizedTokens, shareNumerator), shareDenominator);
        uint jarShare = sub_(seizedTokens, memberShare);

        IERC20(cTokenCollateral).safeTransfer(member, memberShare);
        IERC20(cTokenCollateral).safeTransfer(jar, jarShare);
    }

    function membersLength() external view returns (uint) {
        return members.length;
    }

    function getMembers() external view returns (address[] memory) {
        return members;
    }

    function _isETH(address addr) internal pure returns (bool) {
        return addr == ETH_ADDR;
    }

    function _isCEther(address addr) internal view returns (bool) {
        return addr == cEther;
    }

    function _getUnderlying(address cToken) internal view returns (address underlying) {
        if(_isCEther(cToken)) {
            underlying = ETH_ADDR;
        } else {
            underlying = address(ICErc20(cToken).underlying());
        }
    }
}
