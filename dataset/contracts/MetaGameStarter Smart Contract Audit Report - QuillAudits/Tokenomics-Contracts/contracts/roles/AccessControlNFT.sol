// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./Interfaces/IUniswapV2PairGetReserves.sol";

import "./LibRoles.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./ERC721Trimmed.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract AccessControlNFT is ERC721TrimmedUpgradeable, OwnableUpgradeable, IAccessControlNFT {
    using SafeERC20 for IERC20;
    using LibRoles for User;
    using LibRoles for RoleData;
    using MerkleProof for bytes32[];

    uint256 constant internal PERCENT = 100;
    uint256 constant internal BASIS_POINTS = 10_000;
    uint256 constant internal ORACLE_DECIMALS = 10 ** 8;
    
    address internal _revenueSplitter;
    address internal _mghWMaticPair;
    uint256 internal _mghRebatePercentage;

    bytes32 public referralMessageHash = ECDSA.toEthSignedMessageHash(bytes("MGH Roles Referral\nChain:137\nVersion: 1.0"));

    mapping(address => User) internal _user;
    mapping(uint8 => RoleData) internal _roleData;
    mapping(address => CurrencyData) internal _currencyData;
    mapping(uint256 => Airdrop) internal _airdropById;
    mapping(address => mapping(uint256 => bool)) internal _airdropClaimed;

    // serves only as a sanity check
    modifier isContract(address account) {
        require(account.code.length > 0, "address should have code");
        _;
    }

    // auto initialize the contract, since it will serve as the implementation for a proxy
    constructor() initializer {}

    function initialize(
        RoleSetup memory rolesSetupData,
        Tier[] memory enabledTiers,
        uint256[] memory feeByTier,
        address[] memory currencies,
        address revenueSplitter,
        address mghWMaticPair,
        uint256 mghRebate
    ) external initializer {
        __Ownable_init();
        __ERC721_init("MGH_API", "MGH_API");

        setupRole(rolesSetupData, enabledTiers, feeByTier);

        setMGHRebate(mghRebate);
        setRevenueSplitter(revenueSplitter);
        setMghPool(mghWMaticPair);

        for(uint256 i = 0; i < currencies.length; i = i + 2) {
            setCurrency(currencies[i], currencies[i+1]);
        }

    }

    function purchaseRole(
        GiveRoleParams memory params,
        address currency,
        bytes memory referralSig
    ) public payable override returns(uint256) {

        RoleData storage roleData = _roleData[params.roleId];
        User storage user = _user[params.recipient];
        CurrencyData memory currencyData = _currencyData[currency];

        uint256 roleIndex = user.roleIndex(params.roleId);
        uint256 feeForTier = roleData.feeByTier[params.tier];
        uint256 amountToPayInUSD = params.intervals * feeForTier;

        require(roleData.isPurchaseable, "role not active");
        require(feeForTier != 0, "tier not active");
        require(params.intervals <= roleData.maxIntervalsAtOnce, "too many intervals");
        require(currencyData.oracle != address(0), "currency not accepted");

        // calculate amountToPayInUSD change because of tiers: 
        if(roleIndex != type(uint256).max) {
            UserRoleData storage userRoleData = user.userRoleDataArray[roleIndex];
            uint256 intervalsLeft_100 = _intervalsLeft_100(roleData.intervalLength, userRoleData.expiration);
            Tier currentTier = userRoleData.tier;        
            if (currentTier != params.tier && intervalsLeft_100 > 0) {
                // user already has the role, so we deduct from payment,
                // if new tier is lower and add upgrade fee, if new tier is higher

                // case 1: user downgrades tier
                if(currentTier > params.tier) {
                    uint256 refundAmount = intervalsLeft_100 * (roleData.feeByTier[currentTier] - feeForTier) / PERCENT;
                    amountToPayInUSD = refundAmount >= amountToPayInUSD ? 0 : amountToPayInUSD - refundAmount;
                } 
                // case 2: user upgrades tier
                else {
                    amountToPayInUSD += intervalsLeft_100 * (feeForTier - roleData.feeByTier[currentTier]) / PERCENT;
                }
            }
        }

        // apply rebate for mass purchase and then for paying with MGH in no particular order
        // mass purchase rebate
        if(params.intervals > 1 && roleData.rebatePerInterval != 0) {
            uint256 rebatePercentage = Math.min(params.intervals * uint256(roleData.rebatePerInterval), roleData.maxRebate);
            amountToPayInUSD = _applyPercentageRebate(amountToPayInUSD, rebatePercentage);
        }
        // rebate for MGH payment on the new value
        if(address(currencyData.oracle) == _mghWMaticPair) {
            amountToPayInUSD = _applyPercentageRebate(amountToPayInUSD, _mghRebatePercentage);
        }

        // apply referral Logic, when you are referred by someone
        uint256 referrerShare = 0;
        address referrer;
        if(balanceOf(params.recipient) == 0) {
            uint256 referralBonusInUSD = roleData.referralBonusInUSD; 
            // first time is more expensive to pay referrers, without messing up incentives
            amountToPayInUSD += referralBonusInUSD;

            if(referralSig.length != 0) {
                referrer = ECDSA.recover(referralMessageHash, referralSig);

                require(_referralApplicable(referrer, referralBonusInUSD), "invalid referral");
                referrerShare = referralBonusInUSD * BASIS_POINTS / amountToPayInUSD;
                require(referrerShare < BASIS_POINTS, "referral unexpectedly big");
            } else {
                amountToPayInUSD += referralBonusInUSD;
            }
        } else { require(referralSig.length == 0, "can only use referral for first purchase"); }

        uint256 amountToPayInCurrency = amountToPayInUSD * ORACLE_DECIMALS * currencyData.tokenDecimals / _queryOracle(currencyData.oracle);
        uint256 referrerAmountInCurrency = referrerShare * amountToPayInCurrency / BASIS_POINTS;

        // process payments separately to avoid stack too deep error
        _processPayment(currency, amountToPayInCurrency, referrerAmountInCurrency, referrer);

        _giveRole(params, roleIndex);

        return amountToPayInCurrency;
    }

    function claimAirdrop(address recipient, uint256 airdropId, bytes32[] memory proof) external {
        Airdrop memory airdrop = _airdropById[airdropId];
        User storage user = _user[recipient];

        require(!_airdropClaimed[recipient][airdropId], "airdrop already claimed");
        require(block.timestamp > airdrop.start && block.timestamp < airdrop.end && airdrop.root != bytes32(0), "airdrop not active");
        if(airdrop.onlyFirstTimeRole) require(user.roleIndex(airdrop.roleId) == type(uint256).max, "only first time role");
        if(airdrop.onlyFirstTime)     require(balanceOf(recipient) == 0, "only first time users");
        require(proof.verify(airdrop.root, keccak256(abi.encodePacked(recipient))), "invalid proof");

        _airdropClaimed[recipient][airdropId] = true;

        GiveRoleParams memory params = GiveRoleParams(recipient, airdrop.roleId, airdrop.tier, airdrop.intervals);
       _giveRole(params, user.roleIndex(airdrop.roleId));
    }

    function donateRolesAsOwner(
        address[] memory recipients, 
        uint8 roleId, 
        Tier tier, 
        uint40  intervals
    )
        public onlyOwner
    {
        uint256 recipientsCount = recipients.length;
        for(uint256 i = 0; i < recipientsCount; i++) {
            address recipient = recipients[i];
            User storage user = _user[recipient];

            uint256 roleIndex = user.roleIndex(roleId);
            Tier betterTier = Tier(Math.max(uint256(tier), roleIndex == type(uint256).max ? 0 : uint256(user.userRoleDataArray[roleIndex].tier)));
            GiveRoleParams memory params = GiveRoleParams(recipients[i], roleId, betterTier, intervals);
            _giveRole(params, roleIndex);
        }
    }

    function revokeRoleAsOwner(address who, uint8 roleId) external onlyOwner {
        User storage user = _user[who];

        uint256 index = user.roleIndex(roleId);
        require(index != type(uint256).max);

        user.indexByRole[roleId] = 0;
        
        // cannot underflow bcs of `require(index != type(uint256).max);` 
        uint256 lastIndex = user.userRoleDataArray.length - 1;

        if(index != lastIndex) {
            uint8 roleIdLastRole = user.userRoleDataArray[lastIndex].roleId;
            user.userRoleDataArray[index] = user.userRoleDataArray[lastIndex];
            user.indexByRole[roleIdLastRole] = index;
        }
        user.userRoleDataArray.pop();
    }
                    

    //// OWNER setter functions ////

    function setupRole(
        RoleSetup memory roleSetup,
        Tier[] memory enabledTiers,
        uint256[] memory feeByTier
    ) public onlyOwner {
        RoleData storage role = _roleData[roleSetup.roleId];

        require(role.intervalLength == 0, "already setup");
        require(roleSetup.intervalLength * roleSetup.maxIntervalsAtOnce > 0, "non zero param is given as 0");
        require(enabledTiers.length == feeByTier.length, "tier fees dont match");
        require(roleSetup.maxRebate <= PERCENT);

        role.isPurchaseable     = roleSetup.isPurchaseable;
        role.callsPerInterval   = roleSetup.callsPerInterval;
        role.intervalLength     = roleSetup.intervalLength;
        role.maxIntervalsAtOnce = roleSetup.maxIntervalsAtOnce;
        role.maxRebate          = roleSetup.maxRebate;
        role.rebatePerInterval  = roleSetup.rebatePerInterval;
        role.referralBonusInUSD = roleSetup.referralBonusInUSD;

        for(uint256 i = 0; i < enabledTiers.length; i++) {
            require(feeByTier[i] != 0, "fee cannot be 0");
            require(enabledTiers[i] != Tier.NO_TIER, "cannot set the NO_TIER");
            role.feeByTier[enabledTiers[i]] = feeByTier[i];
        }
        // emit
    }

    function setFee(uint8 roleId, Tier tier, uint256 feeForTier) public onlyOwner {
        require(_isRoleInitialized(roleId));
        require(tier != Tier.NO_TIER, "cannot set fee for NOTIER");
        _roleData[roleId].feeByTier[tier] = feeForTier;
    }

    function setRoleStatus(uint8 roleId, bool isPurchaseable) public onlyOwner {
        require(_isRoleInitialized(roleId));
        require(isPurchaseable != _roleData[roleId].isPurchaseable, "already set");
         _roleData[roleId].isPurchaseable = isPurchaseable;
    }

    /// careful, the fee is per interval, so this might effectively change the price
    function setIntervalLength(uint8 roleId, uint40 newIntervalLength) public onlyOwner {
        require(_isRoleInitialized(roleId));
        require(newIntervalLength > 0);
        _roleData[roleId].intervalLength = newIntervalLength;
    }

    function setCallsPerInterval(uint8 roleId, uint40 callsPerInterval) public onlyOwner {
        require(_isRoleInitialized(roleId));
        _roleData[roleId].callsPerInterval = callsPerInterval;
    }

    function setMaxIntervalsAtOnce(uint8 roleId, uint16 newMaxIntervals) public onlyOwner {
        require(_isRoleInitialized(roleId));
        require(newMaxIntervals != 0);
        _roleData[roleId].maxIntervalsAtOnce = newMaxIntervals;
    }

    function setRebate(uint8 roleId, uint8 rebatePerInterval, uint8 maxRebate) public onlyOwner {
        require(_isRoleInitialized(roleId));
        require(maxRebate <= PERCENT);
        RoleData storage roleData = _roleData[roleId];
        roleData.rebatePerInterval = rebatePerInterval;
        roleData.maxRebate = maxRebate;
    }

    function setReferralMessage(string memory newReferralMessage) external onlyOwner {
        require(bytes(newReferralMessage).length != 0);
        referralMessageHash = ECDSA.toEthSignedMessageHash(bytes(newReferralMessage));
    }

    function setReferralBonus(uint8 roleId, uint16 referralBonusInUSD) external onlyOwner {
        _roleData[roleId].referralBonusInUSD = referralBonusInUSD;
    }

    function setCurrency(address currency, address oracle) public onlyOwner {
        require(_queryOracle(oracle) > 0, "oracle contract call failed");
        if(oracle != _mghWMaticPair) require(AggregatorV3Interface(oracle).decimals() == 8, "oracle decimals must be 8");
        uint64 tokenDecimals = currency == address(0) ? 18 : IERC20Metadata(currency).decimals();
        _currencyData[currency] = CurrencyData(oracle, uint64(10) ** tokenDecimals);
    }

    function registerAirdrop(uint256 airdropId, Airdrop memory airdrop) external onlyOwner {
        Airdrop storage emptyAirdrop = _airdropById[airdropId];
        require(emptyAirdrop.intervals == 0, "airdropId already used");
        require(airdrop.intervals > 0, "airdrop needs interval");
        require(airdrop.root != bytes32(0), "root not set");

        _airdropById[airdropId] = airdrop;
    }

    function extendAirdrop(uint256 airdropId, bytes32 root, uint256 newEnd) external onlyOwner {
        Airdrop storage airdrop = _airdropById[airdropId];

        require(airdrop.intervals > 0, "airdrop not set");
        require(airdrop.root != root, "root already set");

        airdrop.root = root;
        airdrop.end  = uint40(newEnd);
    }

    function setUsedCalls(address account, uint8 roleId, uint40 callsUsedTotal) public onlyOwner {
        uint256 index = _user[account].indexByRole[roleId]; 
        _user[account].userRoleDataArray[index].callsUsedTotal = callsUsedTotal;
    }

    function setRevenueSplitter(address revenueSplitter) public onlyOwner isContract(revenueSplitter) {
        _revenueSplitter = revenueSplitter;
    }

    function setMGHRebate(uint256 mghRebatePercentage) public onlyOwner {
        require(mghRebatePercentage < PERCENT);
        _mghRebatePercentage = mghRebatePercentage;
    }

    function setMghPool(address pairContract) public onlyOwner isContract(pairContract) {
        _mghWMaticPair = pairContract;
    }

    //// Owner Token Recovery////
    function recoverToken(address token) external onlyOwner {
        if(token == address(0)) {
            msg.sender.call{ value: address(this).balance }("");
        } else {
            IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
        }
    }


    //// VIEWS ////

    function getRoleInfo(uint8 roleId) external view returns(bool isPurchaseable, uint40 intervalLength, uint40 callsPerInterval) {
        RoleData storage role = _roleData[roleId];
        isPurchaseable = role.isPurchaseable;
        intervalLength = role.intervalLength;
        callsPerInterval = role.callsPerInterval;
    }

    function getTierInfo(uint8 roleId, Tier tier) external view returns(bool isPurchaseable, uint256 fee) {
        RoleData storage role = _roleData[roleId];
        fee = role.feeByTier[tier];
        isPurchaseable = role.isPurchaseable && fee != 0;
    }

    function getCurrencyInfo(address currency) public view returns(CurrencyData memory) {
        return _currencyData[currency];
    }

    function getUserRoleSingle(address account, uint8 roleId) public view returns(bytes32 ret) {
        uint256 mapSlot;
        uint256 userRoleIndex = _user[account].roleIndex(roleId);
        if(userRoleIndex == type(uint256).max) return bytes32(type(uint256).max);
        assembly {
            mapSlot := _user.slot
        }
        uint256 arrayLengthSlot = uint256(keccak256(abi.encodePacked(uint256(uint160(account)), mapSlot)));
        uint256 roleSlot = uint256(keccak256(abi.encodePacked(arrayLengthSlot))) + userRoleIndex;
        assembly {
            ret := sload(roleSlot)
        }
    }

    function getUserRolesComplete(address account) public view returns(bytes32[] memory ret) {
        uint256 mapSlot;
        assembly {
            mapSlot := _user.slot
        }
        uint256 arrayLengthSlot = uint256(keccak256(abi.encodePacked(uint256(uint160(account)), mapSlot)));
        uint256 firstElementSlot = uint256(keccak256(abi.encodePacked(arrayLengthSlot)));
        uint256 length;
        assembly {
            length := sload(arrayLengthSlot)
        }
        if(length == 0) return new bytes32[](1);
        
        ret = new bytes32[](length);
        for(uint256 i = 0; i < length; i++) {
            bytes32 slotData;
            assembly {
                slotData := sload(add(firstElementSlot, i))
            }
            ret[i] = slotData;
        }
    }

    function getUserRoleSingleAsStruct(address account, uint8 roleId) public view returns(UserRoleData memory) {
        uint256 userRoleIndex = _user[account].roleIndex(roleId);
        if(userRoleIndex == type(uint256).max) return UserRoleData(roleId, Tier.NO_TIER, 0, 0, 0);

        return _user[account].userRoleDataArray[userRoleIndex];
    }

    function getUserRolesCompleteAsStruct(address account) public view returns(UserRoleData[] memory) {
        return _user[account].userRoleDataArray;
    }

    // INTERNALS

    function _mint(address recipient) internal {
        _mint(recipient, (uint160(recipient)));
    }

    function _giveRole(GiveRoleParams memory params, uint256 roleIndex) internal {
        require(params.recipient != address(0), "ZERO_ADDRESS");

        User storage user = _user[params.recipient];
        RoleData storage role = _roleData[params.roleId];

        if(roleIndex == type(uint256).max) {
            require(params.intervals > 0, "amount to purchase cannot be 0");

            if(balanceOf(params.recipient) == 0) _mint(params.recipient);

            user.indexByRole[params.roleId] = user.userRoleDataArray.length;

            uint40 expiration = uint40(params.intervals * role.intervalLength + block.timestamp);
            uint40 callsTotal = uint40(params.intervals * role.callsPerInterval);

            user.userRoleDataArray.push(
                UserRoleData(
                    params.roleId,
                    params.tier,
                    expiration,
                    callsTotal,
                    0
                )
            );
        }
        else {
            UserRoleData storage userRoleData = user.userRoleDataArray[roleIndex];

            uint40 callsTotal = userRoleData.callsTotal + uint40(params.intervals * role.callsPerInterval);
            uint40 expiration = uint40(Math.max(userRoleData.expiration, block.timestamp) + params.intervals * role.intervalLength);

            userRoleData.callsTotal = callsTotal;
            userRoleData.expiration = expiration;
            userRoleData.tier = params.tier;
        }
        emit RoleChanged(params.recipient, getUserRoleSingle(params.recipient, params.roleId));
    }

    function _processPayment(address currency, uint256 amountToPayInCurrency, uint256 referrerAmountInCurrency, address referrer) internal {
        if(currency == address(0)) {
            require(msg.value >= amountToPayInCurrency, "not enough native currency sent");
            _revenueSplitter.call{ value: amountToPayInCurrency - referrerAmountInCurrency }("");
            // referrer can only be EOA, since we do not support EIP1271
            if(referrerAmountInCurrency != 0) referrer.call{ value: referrerAmountInCurrency }("");
            // refund native currency. Reentrancy to this contract is of no use for the user
            msg.sender.call{ value: msg.value - amountToPayInCurrency }("");
        } else {
            require(msg.value == 0, "send either token or native");
            IERC20(currency).safeTransferFrom(msg.sender, _revenueSplitter, amountToPayInCurrency - referrerAmountInCurrency);
            if(referrerAmountInCurrency != 0) IERC20(currency).safeTransferFrom(msg.sender, referrer, referrerAmountInCurrency);
        }
    }

    function _applyPercentageRebate(uint256 initialValue, uint256 percentage) internal pure returns(uint256) {
        require(percentage <= PERCENT, "percentage out of bound");
        return initialValue * (PERCENT - percentage) / PERCENT;
    }

    function _isRoleInitialized(uint8 roleId) internal view returns(bool) {
        return _roleData[roleId].intervalLength != 0;
    }

    function _intervalsLeft_100(uint256 intervalLength, uint256 expiration) internal view returns(uint256) {
        if (expiration <= block.timestamp) return 0;
        
        uint256 timeLeft = expiration - block.timestamp;
        return timeLeft * PERCENT / intervalLength;
    }

    function _queryOracle(address oracle) internal view returns(uint256) {
        // if token is MGH (no oracle provider) we calculate based on the Quickswap LP
        if(oracle == _mghWMaticPair) {
            (uint112 wmaticReserve, uint112 mghReserve, ) = IUniswapV2PairGetReserves(_mghWMaticPair).getReserves();
            (, int maticPrice,,,) = AggregatorV3Interface(_currencyData[address(0)].oracle).latestRoundData();
            if(maticPrice <= 0) revert("invalid price feed");
            // both tokens have 18 decimals, the 8 oracle decimal places are included in `maticPrice`
            return uint256(maticPrice) * wmaticReserve / mghReserve;
        }
        (, int price,,,) = AggregatorV3Interface(oracle).latestRoundData();
        if(price <= 0) revert("invalid price feed");

        return uint256(price);
    }

    function _referralApplicable(address referrer, uint256 referralBonus) internal view returns(bool) {
        // referrer != addresss(0) is implied by balanceOf(referrer) != 0;
        return  balanceOf(referrer) != 0 &&
                !_isContract(referrer) &&
                referralBonus > 0;
    }

    function _isContract(address account) internal view returns(bool) {
        return account.code.length > 0;
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        require(from == address(0) || to == address(0), "not transferable");
    }
}