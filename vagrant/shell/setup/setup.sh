#!/usr/bin/bash

. ~/.bashrc

# install rpms, then remove pulp*
echo "installing RPMs"
sudo dnf install -y git python-gofer-qpid python-qpid python-qpid-qmf \
                    python-setuptools python-sphinx qpid-cpp-server qpid-cpp-server-store

echo "Starting qpidd"
sudo systemctl enable qpidd
sudo systemctl start qpidd


pushd devel
for r in {pulp,pulp_deb,pulp_docker,pulp_openstack,pulp_ostree,pulp_puppet,pulp_python,pulp_rpm}; do
  if [ -d $r ]; then
    echo "installing $r dev code"
    pushd $r
    # This command has an exit code of 1 when it works?
    ! mkvirtualenv --system-site-packages $r
    workon $r
    setvirtualenvproject
    sudo dnf install -y $(rpmspec -q --queryformat '[%{REQUIRENAME}\n]' *.spec | grep -v "/.*" | grep -v "python-pulp.* " | grep -v "pulp.*" | uniq)
    # Install dependencies for automated tests
    pip install -r test_requirements.txt
    sudo python ./pulp-dev.py -I
    deactivate
    popd
  fi
done
# If crane is present, let's set it and its dependencies up as well
if [ -d crane ]; then
    echo "installing crane's environment"
    pushd crane
    ! mkvirtualenv --system-site-packages crane
    workon crane
    setvirtualenvproject
    # Install dependencies
    sudo dnf install -y $(rpmspec -q --queryformat '[%{REQUIRENAME}\n]' python-crane.spec | grep -v "/.*" | uniq)
    pip install -r test-requirements.txt

    cat << EOF > /home/vagrant/devel/crane/crane.conf
[general]
data_dir: /home/vagrant/devel/crane/metadata
debug: true
endpoint: pulp-devel:5001
EOF

    mkdir -p metadata
    sudo ln -s /home/vagrant/devel/crane/metadata/ /var/lib/pulp/published/docker/app

    deactivate
    popd
fi
popd


# If there is no .vimrc, give them a basic one
if [ ! -f /home/vagrant/.vimrc ]; then
    echo -e "set expandtab\nset tabstop=4\nset shiftwidth=4\n" > /home/vagrant/.vimrc
fi

echo "Adjusting facls for apache"
setfacl -m user:apache:rwx /home/vagrant

echo "populating mongodb"
sudo -u apache pulp-manage-db

# Enable and start the Pulp services
echo "Starting more services"
for s in goferd httpd pulp_workers pulp_celerybeat pulp_resource_manager; do
  sudo systemctl enable $s
done
pstart

echo "Disabling SSL verification on dev setup"
sudo sed -i 's/# verify_ssl: True/verify_ssl: False/' /etc/pulp/admin/admin.conf

if [ ! -f /home/vagrant/.pulp/user-cert.pem ]; then
    echo "Logging in"
    pulp-admin login -u admin -p admin
fi

if [ -d /home/vagrant/devel/pulp_rpm ]; then
    if [ "$(pulp-admin rpm repo list | grep zoo)" = "" ]; then
        echo "Creating the example zoo repository"
        pulp-admin rpm repo create --repo-id zoo --feed \
            https://repos.fedorapeople.org/repos/pulp/pulp/demo_repos/zoo/ --relative-url zoo
    fi
fi

# Give the user some use instructions
sudo cp /home/vagrant/devel/pulp/playpen/vagrant-motd.txt /etc/motd
echo -e '\n\nDone. You can ssh into your development environment with vagrant ssh.\n'
