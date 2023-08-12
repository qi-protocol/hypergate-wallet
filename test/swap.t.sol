// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {ERC20} from "contracts/UniswapV2/TestERC20.sol";
import {WETH9} from "contracts/UniswapV2/WETH9.sol";
import {UniswapV2Factory} from "contracts/UniswapV2/UniswapV2Factory.sol";
import {UniswapV2Pair} from "contracts/UniswapV2/UniswapV2Pair.sol";
import {UniswapV2Router02} from "contracts/UniswapV2/UniswapV2Router.sol";

contract swap is Test {
    ERC20 public token;
    WETH9 public weth;
    UniswapV2Factory public uniswapV2Factory;
    UniswapV2Router02 public uniswapV2Router02;
    UniswapV2Pair public uniswapV2Pair;
    address owner;
    address[2] path;

    function setUp() public {
        token = new ERC20("TestToken", "TEST");
        weth = new WETH9();
        uniswapV2Factory = new UniswapV2Factory(owner);
        uniswapV2Router02 = new UniswapV2Router02(address(uniswapV2Factory), address(weth));
        uniswapV2Pair = UniswapV2Pair(uniswapV2Factory.createPair(address(token), address(weth)));

        vm.startPrank(owner);
        token = new ERC20("TestToken", "TEST");
        weth = new WETH9();
        uniswapV2Factory = new UniswapV2Factory(owner);
        uniswapV2Router02 = new UniswapV2Router02(address(uniswapV2Factory), address(weth));
        uniswapV2Pair = UniswapV2Pair(uniswapV2Factory.createPair(address(token), address(weth)));
        vm.deal(owner, 10 ether);
        
        bytes memory payload = abi.encodeWithSignature("deposit()");
        (bool success,) = address(weth).call{value: 10 ether}(payload);
        require(success);
        require(weth.balanceOf(owner) > 0);
        token.mintMore(address(owner), 10000000);
        token.transfer(owner, token.balanceOf(owner));
        weth.transfer(owner, token.balanceOf(owner));
        uniswapV2Pair.sync();
        path[0] = address(weth);
        path[1] = address(token);
    }

    function swap_payload(address wallet) public view returns(bytes memory) {
        return abi.encodeWithSignature("swapExactETHForTokensSupportingFeeOnTransferTokens(uint,address[],address,uint)",0,path,wallet,block.timestamp + 3600);
    }
}