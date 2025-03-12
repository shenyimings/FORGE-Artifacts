/// StakingRewardsEscrow.sol

// Copyright (C) 2021 Reflexer Labs, INC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.7;

import "./utils/ReentrancyGuard.sol";

abstract contract TokenLike {
    function balanceOf(address) virtual public view returns (uint256);
    function transfer(address, uint256) virtual external returns (bool);
}

contract StakingRewardsEscrow is ReentrancyGuard {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "StakingRewardsEscrow/account-not-authorized");
        _;
    }

    // --- Structs ---
    struct EscrowSlot {
        uint256 total;
        uint256 startDate;
        uint256 duration;
        uint256 claimedUntil;
        uint256 amountClaimed;
    }

    // --- Variables ---
    // The address allowed to request escrows
    address   public escrowRequestor;
    // The time during which a chunk is escrowed
    uint256   public escrowDuration;
    // Time in a slot during which rewards to escrow can be added without creating a new escrow slot
    uint256   public durationToStartEscrow;
    // The token to escrow
    TokenLike public token;

    uint256   public constant MAX_ESCROW_DURATION          = 180 days;
    uint256   public constant MAX_DURATION_TO_START_ESCROW = 30 days;
    uint256   public constant MAX_SLOTS_TO_CLAIM           = 15;

    // Next slot to fill for every user
    mapping (address => uint256)                        public currentEscrowSlot;
    // All escrows for all accounts
    mapping (address => mapping(uint256 => EscrowSlot)) public escrows;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(bytes32 indexed parameter, uint256 data);
    event ModifyParameters(bytes32 indexed parameter, address data);
    event EscrowRewards(address indexed who, uint256 amount, uint256 currentEscrowSlot);
    event ClaimRewards(address indexed who, uint256 amount, uint256 startRange, uint256 endRange);

    constructor(
      address escrowRequestor_,
      address token_,
      uint256 escrowDuration_,
      uint256 durationToStartEscrow_
    ) public {
      require(escrowRequestor_ != address(0), "StakingRewardsEscrow/null-requestor");
      require(token_ != address(0), "StakingRewardsEscrow/null-token");
      require(both(escrowDuration_ > 0, escrowDuration_ <= MAX_ESCROW_DURATION), "StakingRewardsEscrow/invalid-escrow-duration");
      require(both(durationToStartEscrow_ > 0, durationToStartEscrow_ < escrowDuration_), "StakingRewardsEscrow/invalid-duration-start-escrow");
      require(escrowDuration_ > durationToStartEscrow_, "StakingRewardsEscrow/");

      authorizedAccounts[msg.sender] = 1;

      escrowRequestor        = escrowRequestor_;
      token                  = TokenLike(token_);
      escrowDuration         = escrowDuration_;
      durationToStartEscrow  = durationToStartEscrow_;

      emit AddAuthorization(msg.sender);
    }

    // --- Boolean Logic ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }

    // --- Math ---
    function addition(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "StakingRewardsEscrow/add-overflow");
    }
    function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "StakingRewardsEscrow/sub-underflow");
    }
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "StakingRewardsEscrow/mul-overflow");
    }

    // --- Administration ---
    /*
    * @notify Modify an uint256 parameter
    * @param parameter The name of the parameter to modify
    * @param data New value for the parameter
    */
    function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
        if (parameter == "escrowDuration") {
          require(both(data > 0, data <= MAX_ESCROW_DURATION), "StakingRewardsEscrow/invalid-escrow-duration");
          require(data > durationToStartEscrow, "StakingRewardsEscrow/smaller-than-start-escrow-duration");
          escrowDuration = data;
        }
        else if (parameter == "durationToStartEscrow") {
          require(both(data > 1, data <= MAX_DURATION_TO_START_ESCROW), "StakingRewardsEscrow/duration-to-start-escrow");
          require(data < escrowDuration, "StakingRewardsEscrow/not-lower-than-escrow-duration");
          durationToStartEscrow = data;
        }
        else revert("StakingRewardsEscrow/modify-unrecognized-param");
        emit ModifyParameters(parameter, data);
    }
    /*
    * @notify Modify an address parameter
    * @param parameter The name of the parameter to modify
    * @param data New value for the parameter
    */
    function modifyParameters(bytes32 parameter, address data) external isAuthorized {
        require(data != address(0), "StakingRewardsEscrow/null-data");

        if (parameter == "escrowRequestor") {
            escrowRequestor = data;
        }
        else revert("StakingRewardsEscrow/modify-unrecognized-param");
        emit ModifyParameters(parameter, data);
    }

    // --- Core Logic ---
    /*
    * @notice Put more rewards under escrow for a specific address
    * @param who The address that will get escrowed tokens
    * @param amount Amount of tokens to escrow
    */
    function escrowRewards(address who, uint256 amount) external nonReentrant {
        require(escrowRequestor == msg.sender, "StakingRewardsEscrow/not-requestor");
        require(who != address(0), "StakingRewardsEscrow/null-who");
        require(amount > 0, "StakingRewardsEscrow/null-amount");

        EscrowSlot memory escrowReward = escrows[msg.sender][currentEscrowSlot[msg.sender]];

        if (
          either(currentEscrowSlot[msg.sender] == 0,
          now > addition(escrowReward.startDate, durationToStartEscrow))
        ) {
          currentEscrowSlot[msg.sender] = addition(currentEscrowSlot[msg.sender], 1);
          escrowReward = EscrowSlot(amount, now, escrowDuration, 0, 0);
        } else {
          escrowReward.total = addition(escrowReward.total, amount);
        }

        emit EscrowRewards(who, amount, currentEscrowSlot[msg.sender]);
    }
    /*
    * @notice Claim vested tokens
    * @param who The address to claim on behalf of
    * @param startRange The slot index from which to start claiming
    * @param endRange The slot index to end claiming at
    */
    function claimTokens(address who, uint256 startRange, uint256 endRange) public nonReentrant {
        require(currentEscrowSlot[who] > 0, "StakingRewardsEscrow/invalid-address");
        require(startRange <= endRange, "StakingRewardsEscrow/invalid-range");
        require(endRange < currentEscrowSlot[who], "StakingRewardsEscrow/invalid-end");
        require(subtract(endRange, startRange) <= MAX_SLOTS_TO_CLAIM, "StakingRewardsEscrow/exceeds-max-slots");

        EscrowSlot memory escrowReward;

        uint256 totalToTransfer;
        uint256 endDate;
        uint256 reward;

        for (uint i = startRange; i < endRange; i++) {
            escrowReward = escrows[who][i];
            endDate      = addition(escrowReward.startDate, escrowReward.duration);

            if (escrowReward.amountClaimed >= escrowReward.total) continue;
            if (both(escrowReward.claimedUntil < endDate, now >= endDate)) {
              totalToTransfer            = addition(totalToTransfer, subtract(escrowReward.total, escrowReward.amountClaimed));
              escrowReward.amountClaimed = escrowReward.total;
              escrowReward.claimedUntil  = now;
              continue;
            }

            reward = subtract(escrowReward.total, escrowReward.amountClaimed) / subtract(endDate, escrowReward.claimedUntil);
            reward = multiply(reward, subtract(now, escrowReward.claimedUntil));
            require(addition(escrowReward.amountClaimed, reward) <= escrowReward.total, "StakingRewardsEscrow/reward-more-than-total");

            totalToTransfer            = addition(totalToTransfer, reward);
            escrowReward.amountClaimed = addition(escrowReward.amountClaimed, reward);
            escrowReward.claimedUntil  = now;
        }

        if (totalToTransfer > 0) {
            require(token.transfer(who, totalToTransfer), "StakingRewardsEscrow/cannot-transfer-rewards");
        }

        emit ClaimRewards(who, totalToTransfer, startRange, endRange);
    }
}
