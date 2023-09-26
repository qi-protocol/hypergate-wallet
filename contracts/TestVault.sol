// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestVault is Ownable {
    function withdraw(address to) public onlyOwner {
        payable(to).call{value: address(this).balance}("");
    }
    function withdrawToken(address token, address to, uint256 amount) public onlyOwner {
        bytes memory payload = abi.encodeWithSignature("transferFrom(address,address,uint256)", address(this), to, amount);
        token.call(payload);
    } 
    receive() external payable {}
}