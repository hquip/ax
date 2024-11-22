  provisioner "file" {
    source      = "./configs"
    destination = "/tmp/configs"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "echo 'Waiting for cloud-init to finish, this can take a few minutes please be patient...'",
      "/usr/bin/cloud-init status --wait",

      "fallocate -l 2G /swap && chmod 600 /swap && mkswap /swap && swapon /swap",
      "echo '/swap none swap sw 0 0' | sudo tee -a /etc/fstab",

      "echo 'Running dist-uprade'",
      "sudo apt update -qq",
      "DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew dist-upgrade -qq",

      "echo 'Installing ufw fail2ban net-tools zsh jq build-essential python3-pip unzip git p7zip libpcap-dev rubygems ruby-dev grc'",
      "sudo apt install fail2ban ufw net-tools zsh zsh-syntax-highlighting zsh-autosuggestions jq build-essential python3-pip unzip git p7zip libpcap-dev rubygems ruby-dev grc -y -qq",

      "ufw allow 22",
      "ufw allow 2266",
      "ufw --force enable",

      "echo 'Creating OP user'",
      "useradd -G sudo -s /usr/bin/zsh -m op",
      "mkdir -p /home/op/.ssh /home/op/c2 /home/op/recon/ /home/op/lists /home/op/go /home/op/bin /home/op/.config/ /home/op/.cache /home/op/work/ /home/op/.config/amass",
      "rm -rf /etc/update-motd.d/*",
      "/bin/su -l op -c 'wget -q https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O - | sh'",
      "chown -R op:users /home/op",
      "touch /home/op/.sudo_as_admin_successful",
      "touch /home/op/.cache/motd.legal-displayed",
      "chown -R op:users /home/op",
      "echo 'op:${var.op_random_password}' | chpasswd",
      "echo 'ubuntu:${var.op_random_password}' | chpasswd",
      "echo 'root:${var.op_random_password}' | chpasswd",

      "echo 'Moving Config files'",
      "mv /tmp/configs/sudoers /etc/sudoers",
      "pkexec chown root:root /etc/sudoers /etc/sudoers.d -R",
      "mv /tmp/configs/bashrc /home/op/.bashrc",
      "mv /tmp/configs/zshrc /home/op/.zshrc",
      "mv /tmp/configs/sshd_config /etc/ssh/sshd_config",
      "mv /tmp/configs/00-header /etc/update-motd.d/00-header",
      "mv /tmp/configs/authorized_keys /home/op/.ssh/authorized_keys",
      "mv /tmp/configs/tmux-splash.sh /home/op/bin/tmux-splash.sh",
      "/bin/su -l op -c 'sudo chmod 600 /home/op/.ssh/authorized_keys'",
      "chown -R op:users /home/op",
      "sudo service sshd restart",
      "chmod +x /etc/update-motd.d/00-header",

      "echo 'Installing Golang ${var.golang_version}'",
      "wget -q https://golang.org/dl/go${var.golang_version}.linux-amd64.tar.gz && sudo tar -C /usr/local -xzf go${var.golang_version}.linux-amd64.tar.gz && rm go${var.golang_version}.linux-amd64.tar.gz",
      "export GOPATH=/home/op/go",

      "echo 'Installing Docker'",
      "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && rm get-docker.sh",
      "sudo usermod -aG docker op",

      "echo 'Installing Interlace'",
      "git clone https://github.com/codingo/Interlace.git /home/op/recon/interlace && cd /home/op/recon/interlace/ && python3 setup.py install",

      "echo 'Optimizing SSH Connections'",
      "/bin/su -l root -c 'echo \"ClientAliveInterval 60\" | sudo tee -a /etc/ssh/sshd_config'",
      "/bin/su -l root -c 'echo \"ClientAliveCountMax 60\" | sudo tee -a /etc/ssh/sshd_config'",
      "/bin/su -l root -c 'echo \"MaxSessions 100\" | sudo tee -a /etc/ssh/sshd_config'",
      "/bin/su -l root -c 'echo \"net.ipv4.netfilter.ip_conntrack_max = 1048576\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"net.nf_conntrack_max = 1048576\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"net.core.somaxconn = 1048576\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"net.ipv4.ip_local_port_range = 1024 65535\" | sudo tee -a /etc/sysctl.conf'",
      "/bin/su -l root -c 'echo \"1024 65535\" | sudo tee -a /proc/sys/net/ipv4/ip_local_port_range'",
      "chmod 600 /home/op/.ssh/authorized_keys",

      "echo 'Downloading Files and Lists'",
      "echo 'Downloading axiom-dockerfiles'",
      "git clone https://github.com/attacksurge/dockerfiles.git /home/op/lists/axiom-dockerfiles",
      "echo 'Downloading permutations'",
      "wget -q -O /home/op/lists/permutations.txt https://gist.github.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw",
      "echo 'Downloading resolvers'",
      "wget -q -O /home/op/lists/resolvers.txt https://raw.githubusercontent.com/trickest/resolvers/master/resolvers.txt",
      "echo 'Downloading trusted resolvers'",
      "wget -q -O /home/op/lists/resolvers_trusted.txt https://raw.githubusercontent.com/six2dez/resolvers_reconftw/master/resolvers_trusted.txt",
      "echo 'Downloading fuzz wordlist'",
      "wget -O /home/op/lists/fuzz_wordlist.txt https://raw.githubusercontent.com/six2dez/OneListForAll/master/onelistforallmicro.txt",

      "echo 'Installing Tools'",
      "echo 'Installing anew'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/tomnomnom/anew@latest'",

      "echo 'Installing Amass'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/owasp-amass/amass/v3/...@master'",

       "echo 'Installing ax framework'",
       "/bin/su -l op -c 'git clone https://github.com/attacksurge/ax.git /home/op/.axiom && cd /home/op/.axiom/interact && ./axiom-configure --shell zsh --unattended --setup'",

      "echo 'Installing commix'",
      "/bin/su -l op -c 'docker image build - < /home/op/lists/axiom-dockerfiles/commix/Dockerfile -t axiom/commix'",

      "echo 'Installing Corsy'",
      "/bin/su -l op -c 'docker image build - < /home/op/lists/axiom-dockerfiles/corsy/Dockerfile -t axiom/corsy'",

      "echo 'Installing crlfuzz'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest'",

      "echo 'Installing dalfox'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/hahwul/dalfox/v2@latest'",

      "echo 'Installing dnsvalidator'",
        "git clone https://github.com/vortexau/dnsvalidator.git /home/op/recon/dnsvalidator && cd /home/op/recon/dnsvalidator/ && sudo python3 setup.py install",

      "echo 'Installing dnsx'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest'",

      "echo 'Installing ffuf'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/ffuf/ffuf/v2@latest'",

      "echo 'Installing gau'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/lc/gau@latest'",

      "echo 'Installing gf'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/tomnomnom/gf@latest'",

      "echo 'Installing Gf-Patterns'",
      "git clone https://github.com/1ndianl33t/Gf-Patterns /home/op/.gf",

      "echo 'Installing github-subdomains'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/gwen001/github-subdomains@latest'",

      "echo 'Installing github-endpoints'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/gwen001/github-endpoints@latest'",


      "echo 'Installing google-chrome'",
      "wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && cd /tmp/ && sudo apt install -y /tmp/chrome.deb -qq && apt --fix-broken install -qq",

      "echo 'Installing gowitness'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/sensepost/gowitness@latest'",

      "echo 'Installing Gxss'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/KathanP19/Gxss@latest'",

      "echo 'Installing httpx'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/projectdiscovery/httpx/cmd/httpx@latest'",

      "echo 'Installing interactsh-client'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest'",

      "echo 'Installing katana'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/projectdiscovery/katana/cmd/katana@latest'",

      "echo 'Installing masscan'",
      "apt install masscan -y -qq",

      "echo 'Installing massdns'",
      "git clone https://github.com/blechschmidt/massdns.git /tmp/massdns; cd /tmp/massdns; make -s; sudo mv bin/massdns /usr/bin/massdns",

      "echo 'Installing nmap'",
      "sudo apt-get -qy --no-install-recommends install alien",
      "/bin/su -l op -c 'wget https://nmap.org/dist/nmap-7.94-1.x86_64.rpm -O /home/op/recon/nmap.rpm && cd /home/op/recon/ && sudo alien ./nmap.rpm && sudo dpkg -i ./nmap*.deb'",

      "echo 'Installing nuclei'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && /home/op/go/bin/nuclei'",

      "echo 'Installing puredns'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/d3mondev/puredns/v2@latest'",

      "echo 'Installing qsreplace'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/tomnomnom/qsreplace@latest'",

      "echo 'Installing s3scanner'",
      "/bin/su -l op -c 'pip3 install s3scanner'",

      "echo 'Installing sqlmap'",
      "git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git /home/op/recon/sqlmap-dev",

      "echo 'Installing mantra'",
      "/bin/su -l op -c '/usr/local/go/bin/go install github.com/MrEmpy/Mantra@latest'",
        
      "echo 'Installing subjs'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install -v github.com/lc/subjs@latest'",

      "echo 'Installing testssl'",
      "git clone --depth 1 https://github.com/drwetter/testssl.sh.git /home/op/recon/testssl.sh",
 
      "echo 'Installing tlsx'",
      "/bin/su -l op -c 'GO111MODULE=on /usr/local/go/bin/go install github.com/projectdiscovery/tlsx/cmd/tlsx@latest'",
      
      "echo 'Installing trufflehog'",
      "/bin/su -l op -c 'docker image build - < /home/op/lists/axiom-dockerfiles/trufflehog/Dockerfile -t axiom/trufflehog'",

      "echo 'Installing wafw00f'",
      "cd /tmp && git clone https://github.com/EnableSecurity/wafw00f && cd wafw00f && sudo python3 setup.py install",

      "echo 'Removing unneeded Docker images'",
      "/bin/su -l op -c 'docker image prune -f'",

      "/bin/su -l op -c '/usr/local/go/bin/go  clean -modcache'",
      "/bin/su -l op -c 'wget -q -O gf-completion.zsh https://raw.githubusercontent.com/tomnomnom/gf/master/gf-completion.zsh && cat gf-completion.zsh >> /home/op/.zshrc && rm gf-completion.zsh && cd'",

      "echo 'Installing awscli'",
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o '/tmp/awscliv2.zip' && cd /tmp && unzip awscliv2.zip && sudo ./aws/install",
       
      "git clone https://github.com/projectdiscovery/nuclei-templates /home/op/recon/nuclei",
      "echo 'Installing Nuclei'",
      "/bin/su -l op -c 'go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest'",
        
      "/bin/su -l root -c 'apt-get clean'",
    ]
    inline_shebang = "/bin/sh -x"
  }
}
