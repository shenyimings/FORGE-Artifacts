//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

interface IRedeemPool {
    /**
     * @notice Emits when tStable token is exchanged for stable token
     * @param account, the number of tokens exchanged
     * @param amount, address of the account receiving the stable token
     */
    event StableWithdrawn(address account, uint amount);

    /**
     * @notice exchange tStable token for the stable token
     * @dev users can directly call this function using EOA after approving `amount`
     * @param amount, the number of tokens to be exchanged
     */
    function redeemStable(uint amount) external;

    /**
     * @notice exchange tStable token for the stable token
     * @dev burns the tStable from msg.sender and sends stable to `account`
     * @param amount, the number of tokens to be exchanged
     * @param account, address of the account that will receive the stable token
     */
    function redeemStableFor(address account, uint amount) external;
}
