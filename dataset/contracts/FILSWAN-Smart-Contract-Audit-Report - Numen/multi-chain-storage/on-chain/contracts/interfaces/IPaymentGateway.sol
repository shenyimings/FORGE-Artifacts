// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

interface IPaymentMinimal {
    struct lockPaymentParam {
        string id; // in filecoin, is CID
        uint256 minPayment;
        uint256 amount;
        uint256 lockTime;
        address recipient;
        uint256 size;
        uint8 copyLimit;
    }

    struct unlockPaymentParam {
        string id; // in filecoin, is CID
        string orderId;
        string dealId;
        uint256 amount;
        address recipient;
    }
    
    struct TxInfo {
        string id; // in filecoin, is CID
        address token;
        uint256 minPayment;
        uint256 lockedFee;
        address owner;
        address recipient;
        uint256 deadline;
        bool _isExisted;
        uint256 size;
        uint8 copyLimit;
        uint256 blockNumber;
    }

    /// @notice Returns the locked balance of caller in specific transaction
    /// @param cId The transaction for which to look up the balance it has
    /// @return tx The transaction object
    function getLockedPaymentInfo(string calldata cId)
        external
        view
        returns (TxInfo memory tx);

    function lockTokenPayment(lockPaymentParam calldata param)
        external
        returns (bool);

    function unlockTokenPayment(unlockPaymentParam calldata param)
        external
        returns (bool);

    function unlockCarPayment(string calldata dealId, string calldata network, address recipient)
        external
        returns (bool);
}
