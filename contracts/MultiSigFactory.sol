// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./MultiSig.sol";

contract MultiSigFactory {
    event CreateMultiSig(address indexed multiSig);

    function createMultiSig(
        address[] memory _owners,
        uint256 _threshold
    ) external {
        MultiSig multiSig = new MultiSig(_owners, _threshold);
        emit CreateMultiSig(address(multiSig));
    }
}
