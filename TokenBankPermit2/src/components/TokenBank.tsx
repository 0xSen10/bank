import { useState, useEffect } from 'react';
// viem工具
import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  formatUnits,
  parseUnits,
  hexToSignature,
} from 'viem';
// 测试网配置
import { sepolia } from 'viem/chains';

// ERC20 合约地址
const TOKEN_ADDRESS = '0xDE784e5EEbdA4cBCe967eA51CF8815f248C9A6C5';
// tokenbank 合约地址
const TOKEN_BANK_ADDRESS = '0xd3AA7Bda2f03DA385Befb7ab8EaAECE4B3d6b8A3'; 
// Permit2 合约地址 (预部署在多个测试网)
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
// 代币 decimals
const TOKEN_DECIMALS = 18; 

// 导入 JSON ABI 文件
import tokenABI from '../abi/Token.json';
import tokenBankABI from '../abi/TokenBank.json';

declare global {
  interface Window {
    ethereum?: any;
  }
}

// 本地存储键名
const WALLET_CONNECTION_KEY = 'tokenbank_wallet_connected';

export function TokenBank() {
  // 添加CSS动画样式
  const fadeInStyle = `
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(-10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .animate-fade-in {
      animation: fadeIn 0.3s ease-out;
    }
    .no-arrows::-webkit-outer-spin-button,
    .no-arrows::-webkit-inner-spin-button {
      -webkit-appearance: none;
      margin: 0;
    }
    .no-arrows[type=number] {
      -moz-appearance: textfield;
    }
  `;

  // 存储参数

  // 钱包地址信息
  const [account, setAccount] = useState<`0x${string}` | null>(null);
  // 账户余额
  const [tokenBalance, setTokenBalance] = useState<string>('0');
   // 代币名称
  const [tokenSymbol, settokenSymbol] = useState<string>('');
  // 存款金额
  const [depositBalance, setDepositBalance] = useState<string>('0');
  // 要存入的金额
  const [amount, setAmount] = useState<string>('');
  // 状态控制
  const [depositLoading, setDepositLoading] = useState(false);
  const [withdrawLoading, setWithdrawLoading] = useState(false);
  const [eip2612Loading, setEip2612Loading] = useState(false);
  const [permit2Loading, setPermit2Loading] = useState(false);
  // 错误信息
  const [error, setError] = useState<string | null>(null);
  // 成功消息
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // PublicClient查询客户端
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http('https://ethereum-sepolia-rpc.publicnode.com'),
  });

  // 获取 WalletClient
  const getWalletClient = () =>{
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('MetaMask is not installed'); // 抛出错误
    }
    // 创建 WalletClient
    return createWalletClient({
      chain: sepolia,
      transport: custom(window.ethereum), 
    });

  }

  // 连接钱包
  const connectWallet = async () => {
    try {
      // 清除之前的错误
      setError(null); 
      // 获取钱包客户端
      const walletClient = getWalletClient(); 
      // 请求用户连接钱包（会弹出 MetaMask 弹窗）
      const accounts = await walletClient.requestAddresses();
      const connectedAccount = accounts[0];
      // 保存第一个账户地址
      setAccount(connectedAccount); 
      
      // 保存连接状态到本地存储
      localStorage.setItem(WALLET_CONNECTION_KEY, connectedAccount);
    } catch (err: any) {
      console.error('连接钱包失败:', err);
      // 判断是否是用户拒绝连接
      setError(
        err.message?.includes('user rejected')
          ? '用户拒绝了连接请求'
          : '连接 MetaMask 失败，请重试'
      );
    }
  };

  // 断开钱包连接
  const disconnectWallet = () => {
    setAccount(null);
    setTokenBalance('0');
    setDepositBalance('0');
    settokenSymbol('');
    setAmount('');
    setError(null);
    
    // 清除本地存储
    localStorage.removeItem(WALLET_CONNECTION_KEY);
  };

  // 自动重连钱包
  const autoReconnectWallet = async () => {
    try {
      const savedAccount = localStorage.getItem(WALLET_CONNECTION_KEY);
      if (!savedAccount || typeof window === 'undefined' || !window.ethereum) {
        return;
      }

      // 检查MetaMask是否仍然连接到这个账户
      const walletClient = getWalletClient();
      const accounts = await walletClient.getAddresses();
      
      if (accounts.includes(savedAccount as `0x${string}`)) {
        setAccount(savedAccount as `0x${string}`);
      } else {
        // 如果账户不再可用，清除本地存储
        localStorage.removeItem(WALLET_CONNECTION_KEY);
      }
    } catch (err) {
      console.error('自动重连失败:', err);
      localStorage.removeItem(WALLET_CONNECTION_KEY);
    }
  };

  // 获取用户余额的函数
  const fetchBalances = async () => {
    // 如果没连接钱包，直接返回
    if (!account) return; 
    try {
      // 并行查询两个数据：用户代币余额 + 在银行的存款
      const [userTokenBalance, tokenSymbol,userDeposit] = await Promise.all([
        // 查询用户钱包里的代币余额
        publicClient.readContract({
          address: TOKEN_ADDRESS,
          abi: tokenABI,
          functionName: 'balanceOf',
          args: [account],
        }),
        // 查询代币名称
        publicClient.readContract({
          address: TOKEN_ADDRESS,
          abi: tokenABI,
          functionName: 'symbol',
          args: [],
        }),
        // 查询用户在 TokenBank 中的存款
        publicClient.readContract({
          address: TOKEN_BANK_ADDRESS,
          abi: tokenBankABI,
          functionName: 'getDeposit',
          args: [account],
        }),
      ]) as [bigint,string, bigint];
      // 将金额转换
      setTokenBalance(formatUnits(userTokenBalance, TOKEN_DECIMALS));
      settokenSymbol(tokenSymbol);
      setDepositBalance(formatUnits(userDeposit, TOKEN_DECIMALS));
    } catch (err) {
      console.error('获取余额失败:', err);
      setError('加载余额失败');
    }
  };


  // 存款操作
  const handleDeposit = async () => {
    if (!account || !amount || parseFloat(amount) <= 0) {
      setError('请输入有效的金额');
      return;
    }
    setDepositLoading(true);
    setError(null);

    try {
      const walletClient = getWalletClient();
      const amountInWei = parseUnits(amount, TOKEN_DECIMALS);

      // 第一步：检查当前授权额度
      const currentAllowance = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: tokenABI,
        functionName: 'allowance',
        args: [account, TOKEN_BANK_ADDRESS],
      }) as bigint;

      // 智能授权逻辑：只有在授权额度不足时才进行授权
      if (currentAllowance < amountInWei) {
        // 授权额度不足，需要先授权
        const approveHash = await walletClient.writeContract({
          account,
          address: TOKEN_ADDRESS,
          abi: tokenABI, 
          functionName: 'approve',
          args: [TOKEN_BANK_ADDRESS, amountInWei],
        });
        // 等待授权交易被区块链确认
        await publicClient.waitForTransactionReceipt({ hash: approveHash });
      }

      // 第二步：调用存款函数
      const depositHash = await walletClient.writeContract({
        account,
        address: TOKEN_BANK_ADDRESS,
        abi: tokenBankABI, 
        functionName: 'deposit',
        args: [amountInWei],
      });
      // 等待存款交易被区块链确认
      await publicClient.waitForTransactionReceipt({ hash: depositHash });

      setSuccessMessage('存款成功！');
      fetchBalances(); // 刷新余额
    } catch (err: any) {
      console.error('存款失败:', err);
      setError(
        err.message?.includes('user rejected')
          ? '用户拒绝了交易'
          : '存款失败'
      );
    } finally {
      setDepositLoading(false);
    }
  };

  // 取款操作
  const handleWithdraw = async () => {
    if (!account || !amount || parseFloat(amount) <= 0) {
      setError('请输入有效的金额');
      return;
    }
    setWithdrawLoading(true);
    setError(null);

    try {
      const walletClient = getWalletClient();
      const amountInWei = parseUnits(amount, TOKEN_DECIMALS);

      const hash = await walletClient.writeContract({
        account,
        address: TOKEN_BANK_ADDRESS,
        abi: tokenBankABI,
        functionName: 'withdraw',
        args: [amountInWei],
      });
      await publicClient.waitForTransactionReceipt({ hash });

      setSuccessMessage('取款成功！');
      fetchBalances();
    } catch (err: any) {
      console.error('取款失败:', err);
      setError(
        err.message?.includes('user rejected')
          ? '用户拒绝了交易'
          : '取款失败'
      );
    } finally {
      setWithdrawLoading(false);
    }
  };

  // EIP2612 签名存款操作 - 全新独立实现
  const handleEIP2612SignatureDeposit = async () => {
    console.log('🚀 开始 EIP2612 签名存款流程');

    if (!account || !amount || Number(amount) <= 0) {
      setError('请输入有效的金额');
      return;
    }

    setEip2612Loading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      const walletClient = getWalletClient(); // 确保此函数返回 createWalletClient({ transport: custom(window.ethereum) })
      const amountInWei = parseUnits(amount, TOKEN_DECIMALS); // bigint

      console.log('💰 amount:', amount, 'amountInWei (bigint):', amountInWei.toString());

      // 1) nonce （bigint）
      const nonceBig = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: tokenABI,
        functionName: 'nonces',
        args: [account],
      }) as bigint;
      console.log('🔢 nonce (bigint):', nonceBig.toString());

      // 2) token name
      const tokenName = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: tokenABI,
        functionName: 'name',
        args: [],
      }) as string;
      console.log('🏷 tokenName:', tokenName);

      // 3) deadline
      const deadlineBig = BigInt(Math.floor(Date.now() / 1000) + 3600); // +1 hour
      console.log('⏰ deadline (bigint):', deadlineBig.toString());

      // === 把所有数值转换为字符串（这样兼容性最好） ===
      const valueStr = amountInWei.toString(); // 十进制字符串
      const nonceStr = nonceBig.toString();
      const deadlineStr = deadlineBig.toString();

      // EIP-712 domain & types
      const domain = {
        name: tokenName,
        version: '1',
        chainId: sepolia.id as number,
        verifyingContract: TOKEN_ADDRESS as `0x${string}`,
      };

      // 显式包含 EIP712Domain 可提升兼容性
      const types = {
        EIP712Domain: [
          { name: 'name', type: 'string' },
          { name: 'version', type: 'string' },
          { name: 'chainId', type: 'uint256' },
          { name: 'verifyingContract', type: 'address' },
        ],
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      };

      const message = {
        owner: account,
        spender: TOKEN_BANK_ADDRESS,
        value: valueStr,     // 字符串
        nonce: nonceStr,     // 字符串
        deadline: deadlineStr// 字符串
      };

      console.log('📋 EIP712 domain:', domain);
      console.log('📋 EIP712 types:', types);
      console.log('📋 EIP712 message:', message);

      // 在发起签名前打个点，确保 walletClient 有 signTypedData 方法
      if (typeof (walletClient as any).signTypedData !== 'function') {
        throw new Error('walletClient 不支持 signTypedData，请确认 getWalletClient 使用 custom(window.ethereum)');
      }

      // 5) 请求签名 — 这里应该弹出签名窗口（如果钱包需要）
      setSuccessMessage('请在钱包中签名（第一步）...');
      console.log('🔔 发起 signTypedData 请求（等待签名）');

      const signature = await (walletClient as any).signTypedData({
        account,
        domain,
        types,
        primaryType: 'Permit',
        message,
      });

      console.log('✍️ signTypedData 返回 signature:', signature);

      // 如果没有返回 signature，则抛错
      if (!signature || typeof signature !== 'string' || !signature.startsWith('0x')) {
        throw new Error('签名失败或返回值异常');
      }

      // 解析 r/s/v （兼容处理：如果 viem 中没有 hexToSignature ，手动解析）
      let r: `0x${string}`, s: `0x${string}`, v: number;
      try {
        // prefer viem helper if存在
        if ((window as any).hexToSignatureHelper) {
          // 占位：如果你在环境中有解析工具
          ({ r, s, v } = (window as any).hexToSignatureHelper(signature));
        } else {
          const sig = signature as string;
          r = `0x${sig.slice(2, 66)}` as `0x${string}`;
          s = `0x${sig.slice(66, 130)}` as `0x${string}`;
          v = parseInt(sig.slice(130, 132), 16);
        }
      } catch (e) {
        console.warn('签名解析失败，signature:', signature, e);
        throw new Error('签名解析失败');
      }

      console.log('🔐 解析签名 -> v:', v, 'r:', r, 's:', s);

      // 6) 调用合约 permitDeposit（上链交易，钱包会弹出交易确认窗口）
      setSuccessMessage('签名完成，正在发送 permitDeposit 交易（第二步）...');
      console.log('📤 调用 permitDeposit 写交易');

      const txHash = await walletClient.writeContract({
        account,
        address: TOKEN_BANK_ADDRESS,
        abi: tokenBankABI,
        functionName: 'permitDeposit',
        args: [account, BigInt(valueStr), BigInt(deadlineStr), v, r, s],
      });

      console.log('📦 permitDeposit txHash:', txHash);
      setSuccessMessage('交易已提交，等待区块确认...');
      await publicClient.waitForTransactionReceipt({ hash: txHash });
      console.log('✅ permitDeposit 已确认');

      setSuccessMessage('EIP2612 签名存款成功');
      await fetchBalances();
    } catch (err: any) {
      console.error('EIP2612 签名存款异常:', err);
      setError('操作被取消');
    } finally {
      setEip2612Loading(false);
    }
  };

  // 检查 Permit2 授权额度
  const checkPermit2Allowance = async (): Promise<bigint> => {
    try {
      const allowance = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: tokenABI,
        functionName: 'allowance',
        args: [account, PERMIT2_ADDRESS],
      }) as bigint;
      console.log('🔍 当前 Permit2 授权额度:', allowance.toString());
      return allowance;
    } catch (err) {
      console.error('检查 Permit2 授权额度失败:', err);
      return BigInt(0);
    }
  };

  // 授权 Permit2 合约
  const approvePermit2 = async (): Promise<boolean> => {
    try {
      const walletClient = getWalletClient();
      
      // 使用最大值授权，避免频繁授权
      const maxAmount = BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');
      
      setSuccessMessage('正在授权 Permit2 合约，请在钱包中确认...');
      console.log('🔓 发起 Permit2 授权交易');

      const txHash = await walletClient.writeContract({
        account,
        address: TOKEN_ADDRESS,
        abi: tokenABI,
        functionName: 'approve',
        args: [PERMIT2_ADDRESS, maxAmount],
      });

      console.log('📦 Permit2 授权 txHash:', txHash);
      setSuccessMessage('授权交易已提交，等待区块确认...');
      
      await publicClient.waitForTransactionReceipt({ hash: txHash });
      console.log('✅ Permit2 授权已确认');
      
      setSuccessMessage('Permit2 授权成功！现在可以进行签名存款...');
      return true;
    } catch (err: any) {
      console.error('Permit2 授权失败:', err);
      setError('Permit2 授权失败或被取消');
      return false;
    }
  };

  // Permit2 签名存款操作
  const handlePermit2SignatureDeposit = async () => {
    console.log('🚀 开始 Permit2 签名存款流程');

    if (!account || !amount || Number(amount) <= 0) {
      setError('请输入有效的金额');
      return;
    }

    setPermit2Loading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      const walletClient = getWalletClient();
      const amountInWei = parseUnits(amount, TOKEN_DECIMALS);

      console.log('💰 amount:', amount, 'amountInWei (bigint):', amountInWei.toString());

      // 步骤 1: 检查 Permit2 授权
      setSuccessMessage('检查 Permit2 授权状态...');
      const currentAllowance = await checkPermit2Allowance();
      
      if (currentAllowance < amountInWei) {
        console.log('⚠️ Permit2 授权不足，需要先授权');
        setSuccessMessage('需要先授权 Permit2 合约...');
        
        const approveSuccess = await approvePermit2();
        if (!approveSuccess) {
          return; // 授权失败，直接返回
        }
        
        // 等待一下让用户看到授权成功的消息
        await new Promise(resolve => setTimeout(resolve, 2000));
      } else {
        console.log('✅ Permit2 授权充足，直接进行签名');
        setSuccessMessage('Permit2 授权充足，开始签名流程...');
      }

      // 步骤 2: 生成 Permit2 签名参数
      const nonce = BigInt(Math.floor(Math.random() * 1000000000));
      console.log('🔢 nonce (bigint):', nonce.toString());

      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // +1 hour
      console.log('⏰ deadline (bigint):', deadline.toString());

      // 步骤 3: Permit2 EIP-712 domain & types
      const domain = {
        name: 'Permit2',
        chainId: sepolia.id as number,
        verifyingContract: PERMIT2_ADDRESS as `0x${string}`,
      };

      const types = {
        PermitTransferFrom: [
          { name: 'permitted', type: 'TokenPermissions' },
          { name: 'spender', type: 'address' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
        TokenPermissions: [
          { name: 'token', type: 'address' },
          { name: 'amount', type: 'uint256' },
        ],
      };

      const message = {
        permitted: {
          token: TOKEN_ADDRESS,
          amount: amountInWei.toString(),
        },
        spender: TOKEN_BANK_ADDRESS,
        nonce: nonce.toString(),
        deadline: deadline.toString(),
      };

      console.log('📋 Permit2 EIP712 domain:', domain);
      console.log('📋 Permit2 EIP712 types:', types);
      console.log('📋 Permit2 EIP712 message:', message);

      // 步骤 4: 请求 EIP-712 签名（免费）
      setSuccessMessage('请在钱包中签名 Permit2 转账授权（免费签名）...');
      console.log('🔔 发起 Permit2 signTypedData 请求');

      const signature = await (walletClient as any).signTypedData({
        account,
        domain,
        types,
        primaryType: 'PermitTransferFrom',
        message,
      });

      console.log('✍️ Permit2 signature:', signature);

      if (!signature || typeof signature !== 'string' || !signature.startsWith('0x')) {
        throw new Error('Permit2 签名失败或返回值异常');
      }

      // 步骤 5: 调用合约 depositWithPermit2（需要 Gas）
      setSuccessMessage('签名完成，正在发送 Permit2 存款交易...');
      console.log('📤 调用 depositWithPermit2 写交易');

      const permit = {
        permitted: {
          token: TOKEN_ADDRESS,
          amount: amountInWei,
        },
        nonce: nonce,
        deadline: deadline,
      };

      const txHash = await walletClient.writeContract({
        account,
        address: TOKEN_BANK_ADDRESS,
        abi: tokenBankABI,
        functionName: 'depositWithPermit2',
        args: [permit, signature, account],
      });

      console.log('📦 depositWithPermit2 txHash:', txHash);
      setSuccessMessage('交易已提交，等待区块确认...');
      await publicClient.waitForTransactionReceipt({ hash: txHash });
      console.log('✅ depositWithPermit2 已确认');

      setSuccessMessage('Permit2 签名存款成功！');
      await fetchBalances();
    } catch (err: any) {
      console.error('Permit2 签名存款异常:', err);
      setError('Permit2 操作失败或被取消');
    } finally {
      setPermit2Loading(false);
    }
  };

  // 当 account 变化时，自动获取余额
  useEffect(() => {
    if (account) {
      fetchBalances();
    }
  }, [account]);

  // 组件挂载时尝试自动重连
  useEffect(() => {
    autoReconnectWallet();
  }, []);

  // 成功消息自动消失
  useEffect(() => {
    if (successMessage) {
      const timer = setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [successMessage]);

  // SSR 安全检查
  if (typeof window === 'undefined') {
    return <div>加载中...</div>;
  }

  // 检查 MetaMask 是否安装
  if (!window.ethereum) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-green-900">
        {/* 主要内容 */}
        <div className="flex items-center justify-center min-h-screen p-4">
          <div className="bg-gradient-to-r from-gray-800 to-gray-900 border border-green-500/30 p-8 rounded-2xl shadow-2xl text-center max-w-md w-full">
            <div className="mb-6">
              <div className="w-16 h-16 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
            <h2 className="text-2xl font-bold text-white mb-4">需要安装 MetaMask</h2>
            <p className="text-green-300 mb-6">请安装 MetaMask 钱包插件以使用此应用</p>
            <a 
              href="https://metamask.io/download/" 
              target="_blank" 
              rel="noopener noreferrer"
              className="inline-block px-6 py-3 bg-gradient-to-r from-green-500 to-green-600 text-white font-semibold rounded-xl hover:from-green-600 hover:to-green-700 transition-all duration-300 transform hover:scale-105 shadow-lg"
            >
              下载 MetaMask
            </a>
          </div>
        </div>
      </div>
    );
  }

  // 未连接钱包时显示连接界面
  if (!account) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-green-900">
        {/* 主要内容 */}
        <div className="flex items-center justify-center min-h-screen p-4">
          <div className="bg-gradient-to-r from-gray-800 to-gray-900 border border-green-500/30 p-8 rounded-2xl shadow-2xl text-center max-w-md w-full">
            <div className="mb-8">
              <div className="w-20 h-20 bg-gradient-to-r from-green-400 to-green-600 rounded-full mx-auto mb-6 flex items-center justify-center animate-pulse">
                <svg className="w-10 h-10 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 8a6 6 0 01-7.743 5.743L10 14l-1 1-1 1H6v2H2v-4l4.257-4.257A6 6 0 1118 8zm-6-4a1 1 0 100 2 2 2 0 012 2 1 1 0 102 0 4 4 0 00-4-4z" clipRule="evenodd" />
                </svg>
              </div>
              <h2 className="text-3xl font-bold text-white mb-2">欢迎使用 TokenBank</h2>
              <p className="text-green-300">安全的去中心化代币存储银行</p>
            </div>
            
            <div className="space-y-4">
              <button
                onClick={connectWallet}
                className="w-full px-6 py-4 bg-gradient-to-r from-green-500 to-green-600 text-white font-semibold rounded-xl hover:from-green-600 hover:to-green-700 transition-all duration-300 transform hover:scale-105 shadow-lg"
              >
                <div className="flex items-center justify-center space-x-2">
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 2L3 7v11a1 1 0 001 1h12a1 1 0 001-1V7l-7-5zM10 12a2 2 0 100-4 2 2 0 000 4z" clipRule="evenodd" />
                  </svg>
                  <span>连接 MetaMask 钱包</span>
                </div>
              </button>
              
              {error && (
                <div className="bg-red-500/20 border border-red-500/50 text-red-300 p-3 rounded-lg">
                  {error}
                </div>
              )}
            </div>

            {/* 功能介绍 */}
            <div className="mt-8 flex flex-wrap justify-center gap-4 sm:gap-6">
              <div className="flex items-center space-x-2 text-green-300">
                <svg className="w-5 h-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span className="text-sm">安全存储</span>
              </div>
              <div className="flex items-center space-x-2 text-green-300">
                <svg className="w-5 h-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span className="text-sm">随时存取</span>
              </div>
              <div className="flex items-center space-x-2 text-green-300">
                <svg className="w-5 h-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span className="text-sm">去中心化</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // 主界面
  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-green-900">
      <style dangerouslySetInnerHTML={{ __html: fadeInStyle }} />
      {/* 顶部导航栏 */}
      <nav className="bg-gray-900/80 backdrop-blur-sm border-b border-green-500/30 sticky top-0 z-50">
        <div className="w-full px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            {/* Logo */}
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 bg-gradient-to-r from-green-400 to-green-600 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2H4zm0 2h12v8H4V6z" clipRule="evenodd" />
                </svg>
              </div>
              <h1 className="text-xl font-bold text-white">
                Token<span className="text-green-400">Bank</span>
              </h1>
            </div>

            {/* 钱包连接状态和按钮 */}
            <div className="flex items-center space-x-2 sm:space-x-4">
              {account && (
                <div className="flex items-center space-x-2 sm:space-x-3 bg-gray-800/50 rounded-lg px-2 sm:px-3 py-2 border border-green-500/30">
                  <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                  <span className="text-green-300 text-xs sm:text-sm font-mono">
                    <span className="sm:hidden">{account.slice(0, 4)}...{account.slice(-2)}</span>
                    <span className="hidden sm:inline">{account.slice(0, 6)}...{account.slice(-4)}</span>
                  </span>
                </div>
              )}
              
              {account ? (
                <button
                  onClick={disconnectWallet}
                  className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium rounded-lg transition-all duration-300 flex items-center space-x-2"
                >
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M3 3a1 1 0 00-1 1v12a1 1 0 102 0V4a1 1 0 00-1-1zm10.293 9.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L14.586 9H7a1 1 0 100 2h7.586l-1.293 1.293z" clipRule="evenodd" />
                  </svg>
                  <span className="hidden sm:inline">断开钱包</span>
                </button>
              ) : (
                <button
                  onClick={connectWallet}
                  className="px-4 py-2 bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 text-white font-medium rounded-lg transition-all duration-300 flex items-center space-x-2"
                >
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 2L3 7v11a1 1 0 001 1h12a1 1 0 001-1V7l-7-5zM10 12a2 2 0 100-4 2 2 0 000 4z" clipRule="evenodd" />
                  </svg>
                  <span className="hidden sm:inline">连接钱包</span>
                </button>
              )}
            </div>
          </div>
        </div>
      </nav>

      {/* 主要内容区域 */}
      <div className="p-4 sm:p-6 lg:p-8">
        <div className="max-w-4xl mx-auto">
          {/* 页面标题 */}
          <div className="text-center mb-8 pt-4">
            <h2 className="text-3xl sm:text-4xl font-bold text-white mb-2">
              去中心化代币银行
            </h2>
            <p className="text-green-300 text-lg">安全存储和管理您的数字资产</p>
          </div>

        {/* 错误提示 */}
        {error && (
          <div className="mb-6 bg-red-500/20 border border-red-500/50 text-red-300 p-4 rounded-xl text-center animate-pulse">
            <div className="flex items-center justify-center space-x-2">
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
              <span>{error}</span>
            </div>
          </div>
        )}

        {/* 成功提示 */}
        {successMessage && (
          <div className="mb-6 bg-green-500/20 border border-green-500/50 text-green-300 p-4 rounded-xl text-center animate-fade-in">
            <div className="flex items-center justify-center space-x-2">
              <svg className="w-5 h-5 text-green-400 animate-bounce" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span className="font-medium">{successMessage}</span>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8">
          {/* 余额卡片 */}
          <div className="space-y-6">
            {/* 代币余额 */}
            <div className="bg-gradient-to-r from-gray-800 to-gray-900 border border-green-500/30 rounded-2xl p-6 shadow-2xl hover:shadow-green-500/20 transition-all duration-300">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-green-300 text-lg font-semibold">钱包余额</h3>
                <div className="w-10 h-10 bg-gradient-to-r from-green-400 to-green-600 rounded-full flex items-center justify-center">
                  <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M4 4a2 2 0 00-2 2v1h16V6a2 2 0 00-2-2H4zM18 9H2v5a2 2 0 002 2h12a2 2 0 002-2V9zM4 13a1 1 0 011-1h1a1 1 0 110 2H5a1 1 0 01-1-1zm5-1a1 1 0 100 2h1a1 1 0 100-2H9z" />
                  </svg>
                </div>
              </div>
              <div className="text-3xl font-bold text-white mb-8">
                {tokenBalance}
              </div>
              <div className="text-green-400 font-semibold">
                {tokenSymbol}
              </div>
            </div>

            {/* 存款余额 */}
            <div className="bg-gradient-to-r from-gray-800 to-gray-900 border border-green-500/30 rounded-2xl p-6 shadow-2xl hover:shadow-green-500/20 transition-all duration-300">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-green-300 text-lg font-semibold">银行存款</h3>
                <div className="w-10 h-10 bg-gradient-to-r from-green-400 to-green-600 rounded-full flex items-center justify-center">
                  <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2H4zm0 2h12v8H4V6z" clipRule="evenodd" />
                  </svg>
                </div>
              </div>
              <div className="text-3xl font-bold text-white mb-8">
                {depositBalance}
              </div>
              <div className="text-green-400 font-semibold">
                {tokenSymbol}
              </div>
            </div>
          </div>

          {/* 操作面板 */}
          <div className="bg-gradient-to-r from-gray-800 to-gray-900 border border-green-500/30 rounded-2xl p-6 shadow-2xl">
            <h3 className="text-green-300 text-xl font-semibold mb-6 text-center">交易操作</h3>
            
            {/* 金额输入 */}
            <div className="mb-6">
              <label className="block text-green-300 text-sm font-medium mb-2">
                输入金额
              </label>
              <div className="relative">
                <input
                  type="number"
                  value={amount}
                  onChange={(e) => {
                    setAmount(e.target.value);
                    setError(null);
                  }}
                  placeholder="0.00"
                  className="w-full p-4 bg-gray-700 border border-gray-600 rounded-xl text-white placeholder-gray-400 focus:border-green-500 focus:ring-2 focus:ring-green-500/20 transition-all duration-300 no-arrows"
                  min="0"
                  step="any"
                  autoComplete="off"
                  list=""
                />
                <div className="absolute right-4 top-1/2 transform -translate-y-1/2 text-green-400 font-semibold">
                  {tokenSymbol}
                </div>
              </div>
            </div>

            {/* 操作按钮 */}
            <div className="flex flex-col sm:flex-row gap-4">
              <button
                onClick={handleDeposit}
                disabled={depositLoading}
                className="flex-1 px-6 py-4 bg-gradient-to-r from-green-500 to-green-600 text-white font-semibold rounded-xl hover:from-green-600 hover:to-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105 shadow-lg"
              >
                <div className="flex items-center justify-center space-x-2">
                  {depositLoading ? (
                    <>
                      <svg className="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      <span>处理中...</span>
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v3.586L7.707 9.293a1 1 0 00-1.414 1.414l3 3a1 1 0 001.414 0l3-3a1 1 0 00-1.414-1.414L11 10.586V7z" clipRule="evenodd" />
                      </svg>
                      <span>存款</span>
                    </>
                  )}
                </div>
              </button>

              <button
                onClick={handleWithdraw}
                disabled={withdrawLoading}
                className="flex-1 px-6 py-4 bg-gradient-to-r from-gray-600 to-gray-700 text-white font-semibold rounded-xl hover:from-gray-700 hover:to-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105 shadow-lg border border-gray-500"
              >
                <div className="flex items-center justify-center space-x-2">
                  {withdrawLoading ? (
                    <>
                      <svg className="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      <span>处理中...</span>
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v3.586l-1.293-1.293a1 1 0 00-1.414 1.414l3 3a1 1 0 001.414 0l3-3a1 1 0 00-1.414-1.414L11 10.586V7z" clipRule="evenodd" />
                      </svg>
                      <span>取款</span>
                    </>
                  )}
                </div>
              </button>
            </div>


            {/* EIP2612 签名存款 - 全新独立按钮 */}
            <div className="mt-6">
              <button
                onClick={handleEIP2612SignatureDeposit}
                disabled={eip2612Loading}
                className="w-full px-6 py-4 bg-gradient-to-r from-blue-500 to-blue-600 text-white font-semibold rounded-xl hover:from-blue-600 hover:to-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105 shadow-lg border border-blue-400"
              >
                <div className="flex items-center justify-center space-x-2">
                  {eip2612Loading ? (
                    <>
                      <svg className="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      <span>签名中...</span>
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" clipRule="evenodd" />
                      </svg>
                      <span>EIP2612 签名存款</span>
                    </>
                  )}
                </div>
              </button>
              <div className="mt-2 text-center text-blue-300 text-sm">
                🚀 一键签名存款，无需预先授权，节省 Gas 费用
              </div>
            </div>

            {/* Permit2 签名存款按钮 */}
            <div className="mt-4">
              <button
                onClick={handlePermit2SignatureDeposit}
                disabled={permit2Loading}
                className="w-full px-6 py-4 bg-gradient-to-r from-purple-500 to-purple-600 text-white font-semibold rounded-xl hover:from-purple-600 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105 shadow-lg border border-purple-400"
              >
                <div className="flex items-center justify-center space-x-2">
                  {permit2Loading ? (
                    <>
                      <svg className="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      <span>Permit2 授权中...</span>
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M12.395 2.553a1 1 0 00-1.45-.385c-.345.23-.614.558-.822.88-.214.33-.403.713-.57 1.116-.334.804-.614 1.768-.84 2.734a31.365 31.365 0 00-.613 3.58 2.64 2.64 0 01-.945-1.067c-.328-.68-.398-1.534-.398-2.654A1 1 0 005.05 6.05 6.981 6.981 0 003 11a7 7 0 1011.95-4.95c-.592-.591-.98-.985-1.348-1.467-.363-.476-.724-1.063-1.207-2.03zM12.12 15.12A3 3 0 017 13s.879.5 2.5.5c0-1 .5-4 1.25-4.5.5 1 .786 1.293 1.371 1.879A2.99 2.99 0 0113 13a2.99 2.99 0 01-.879 2.121z" clipRule="evenodd" />
                      </svg>
                      <span>Permit2 签名存款</span>
                    </>
                  )}
                </div>
              </button>
              <div className="mt-2 text-center text-purple-300 text-sm">
                ⚡ 首次使用需授权 Permit2 合约，后续只需签名即可存款
              </div>
            </div>

            {/* 提示信息 */}
            <div className="mt-6 p-4 bg-green-500/10 border border-green-500/30 rounded-xl">
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-green-400 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                </svg>
                <div className="text-green-300 text-sm">
                  <p className="font-medium mb-2">操作流程说明</p>
                  <div className="space-y-1">
                    <p>• <strong>传统存款</strong>：需要两步操作（授权 + 存款）</p>
                    <p>• <strong>EIP2612 签名存款</strong>：一步完成，通过签名授权直接存款</p>
                    <p>• <strong>Permit2 签名存款</strong>：首次需授权 Permit2 合约（最大额度），后续只需签名即可存款</p>
                    <p>• <strong>取款</strong>：直接从银行提取到您的钱包</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
          </div>
        </div>
      </div>
    </div>
  );

}
