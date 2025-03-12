// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../extension/ExtensionReferralSystem.sol";
import "../interfaces/IERC20BM.sol";
import "../partnerProgram/IPartnerProgram.sol";

contract PartnerProgram is
    AccessControl,
    ExtensionReferralSystem,
    IPartnerProgram
{
    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");
    bytes32 public constant INDEX_ROLE = keccak256("INDEX_ROLE");
    bytes32 public constant FABRIC_ROLE = keccak256("FABRIC_ROLE");

    constructor(
        uint256[] memory percentReward,
        address daoAdmin
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DAO_ADMIN_ROLE, daoAdmin);
        _setPercentReward(percentReward);
    }

    function setupRoleIndex(address index) external onlyRole(FABRIC_ROLE) {
        _setupRole(INDEX_ROLE, index);
    }

    function distributeTheReward(
        address referral,
        uint256 amount,
        address token
    ) external onlyRole(INDEX_ROLE) returns (uint256 amountWithoutTax) {
        return (_distributeTheReward(referral, amount, token));
    }

    /// @notice set the referrer
    /// @param referrer rspecify the referrer address
    function setReferrer(address referrer) external {
        require(mapReferrer[msg.sender] == address(0), "You have referrer");
        require(referrer != msg.sender, "You can't be a referrer");
        _setReferrer(msg.sender, referrer);
    }

    /// @notice Sets the amount of the reward and the number of levels in the referral program
    /// @dev The number of levels depends on the size of the array.
    /// * the data inside the array shows the percentage of reward at each level
    /// * Can only be called by a user with the right DAO_ADMIN_ROLE
    /// @param percentReward the data must be specified taking into account the precission
    /// * the amount of data inside the array is equal to the number of levels
    /// * example [10000000, 5000000] equal first level =10%, second level = 5%
    function setPercentReward(uint256[] memory percentReward)
        external
        onlyRole(DAO_ADMIN_ROLE)
    {
        _setPercentReward(percentReward);
    }

    function _send(
        address account,
        uint256 value,
        address token
    ) internal override {
        IERC20BM(token).mint(account, value);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IPartnerProgram).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
