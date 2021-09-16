+++
date = "2021-09-15"
title = "Learning stuff: Pulumi for AWS"
tags = [
  "pulumi",
  "infrastructure",
  "iac",
  "aws",
  "cloud",
  "golang",
	"terraform"
]
categories = [
  "Open source",
  "AWS",
	"DevOps"
]
+++

I decided to make a habit of learning at least one new tool, technology every month and prepare a blog post about it.
In recent months I focused mostly on the stuff I was dealing at work.
Right now I'm reading "Atomic Habits" by James Clear, so that's the first habit I would like to create. :)

## What is Pulumi

This month I decided to check out [Pulumi](https://www.pulumi.com/).
Pulumi is an open-source infrastructure as code tool. It tackles the same problem Terraform, CloudFormation or ARM templates do, so to define, create and manage cloud infrastructure via source code.
The thing that sets Pulumi apart is the fact, that you use a general-purpose programming language to define infrastructure.
Languages supported currently are TypeScript, JavaScript, Python and Go. This makes Pulumi an interesting choice for software developers, who have to manage infrastructure, but don't want to learn a new language.

I tried to deploy a few common infrastructure parts, so I can compare Pulumi to Terraform and CloudFormation.
 
## Cases

### Deploying a simple AWS VPC

To start off, I always need a VPC on AWS. So I need to create:
- VPC
- Private and public subnets per availability zone
- Internet Gateway
- NAT Gateway

In Pulumi I have to start by creating a project (could be compared to a Terraform root module or CloudFormation template). This is where you write your program and where you can define stacks (could be compared to Terraform workspaces and CloudFormation stacks).
Pulumi, similarly to Terraform, also stores the infrastructure metadata in a state. Unlike Terraform, they encourage you to use their free hosted backend to store the state, so you don't have to provision an S3 bucket and do the state management on your own. Cool, I don't really like the state management in Terraform (You need a S3 bucket, but how to create it? A chicken or egg problem). But you store and manage the state on your own S3 bucket or other backend, if you want.
You can read more about the Pulumi concepts [here](https://www.pulumi.com/docs/intro/concepts/).

I decided to write the infrastructure code in Go. My code for the simple VPC is available [here](https://github.com/Trojan295/pulumi-poc/blob/master/projects/simple-vpc/main.go).
To be honest, I have mixed feelings about it. It feels verbose, and I had to write quite a lot of code to achieve a really basic VPC setup. A lot of code is about transforming values to the correct Go structs for Pulumi. AFAIK it's required so Pulumi can track the dependencies and build a DAG for the resources.

```go
// Create a AWS VPC resource
vpc, err := ec2.NewVpc(ctx, "vpc", &ec2.VpcArgs{
	CidrBlock: pulumi.String("10.0.0.0/16"),
	Tags:      pulumi.ToStringMap(map[string]string{
    "Name": "my-vpc",
  }),
})
```

I don't really like the amount of code I had to write. Someone could argue that in CloudFormation or Terraform you also have to write a lot of code. Right, but HCL or YAML feels to me much lighter and easier to use. I don't have to deal with the complexity of a general-purpose language.

Having in mind, that it's a general-purpose language I tried to search for libraries, which could lower the amount of code I have to write.
In Terraform I very often use modules like [this VPC module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest), so can have a full-blown VPC using a dozen lines.
To my surprise, I was not able to find anything in Go! I found [Pulumi Crosswalk](https://www.pulumi.com/docs/guides/crosswalk/aws/), but it's only for TypeScript.

I decided to try to modularize the code on my own.

### Creating an AWS VPC Pulumi module

As I was not able to find any library, which would simplify my VPC code, I prepared a Go package for a complete VPC module. The code is [here](https://github.com/Trojan295/pulumi-poc/blob/master/pkg/vpc/vpc.go). It creates a VPC, subnets, Internet gateway and NAT gateway and can be used the following way:

```go
import (
	"github.com/Trojan295/pulumi-poc/pkg/vpc"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		vpcOutput, err := vpc.NewVpc(ctx, &vpc.VpcInput{
			VpcCidrBlock:            "10.0.0.0/16",
			AvailabilityZones:       []string{"eu-west-1a", "eu-west-1b", "eu-west-1c"},
			PrivateSubnetCidrBlocks: []string{"10.0.0.0/24","10.0.1.0/24","10.0.2.0/24"},
			PublicSubnetCidrBlocks:  []string{"10.0.100.0/24","10.0.101.0/24","10.0.102.0/24"},
		})
		if err != nil {
			return err
		}

    return nil
  })
}
```

That looks a lot better to me and is kinda similar to how modules are used in Terraform.
I updated my VPC project to use my VPC module. It's available [here](https://github.com/Trojan295/pulumi-poc/tree/master/projects/vpc-modular).

### Host an application in the VPC

Having a VPC I can move to the next part: deploying some application. I took a really basic example: EC2 instances in an Autoscaling Group behind an Elastic LoadBalancer. I wanted to use this exercise to try out another feature of Pulumi: Stack references.
Such pattern is very common in Terraform and CloudFormation. You keep a VPC in one Terraform state and then use a remote state data source to use it in another. It makes it easier to manage large cloud deployments.

Following the module approach I took with the VPC, I prepared some small modules for the [SecurityGroup](https://github.com/Trojan295/pulumi-poc/blob/master/pkg/ec2/sg.go), [ELB](https://github.com/Trojan295/pulumi-poc/blob/master/pkg/elb/elb.go) and [ASG](https://github.com/Trojan295/pulumi-poc/blob/master/pkg/ec2/asg.go) and created another Pulumi project, which uses those modules and references the VPC project. Code for the application Pulumi project is [here](https://github.com/Trojan295/pulumi-poc/blob/master/projects/app-modular/main.go).

It doesn't look bad, although I don't like the transformations I need to do to read the subnet IDs from the VPC stack.

```go
vpcStackName := fmt.Sprintf("Trojan295/vpc-modular/%s", ctx.Stack())
vpcStack, _ := pulumi.NewStackReference(ctx, vpcStackName, nil)

publicSubnets := vpcStack.GetOutput(pulumi.String("publicSubnetIDs")).ApplyT(func(x interface{}) []string {
	y := x.([]interface{})
	r := make([]string, 0)
	for _, item := range y {
		r = append(r, item.(string))
	}
	return r
}).(pulumi.StringArrayOutput)
```

Again the requirement to transform the parameters to the Pulumi input and output structs requires some boilerplate code.
I have not tried to use another programming language, maybe in JavaScript or Python it looks simpler.

## My overall experience

I tried to deploy some simple infrastructure parts using Pulumi to get a grasp on how it feels. I have mixed feelings about it.

Pulumi has the gimmick of using a general-purpose programming language, but to be honest I expected more. The ecosystem around isn't as mature as Terraform or CloudFormation.
I though a big advantage would be, that you can leverage the packaging of the selected language and use code writing by other people, but in case of Go I couldn't find any libraries, which would implement good practice infrastructure blocks.

HCL or YAML are simpler than Go. A Terraform module is a flat project, where you define the resources and modules you want to get and there isn't much complexity behind it. When using a language like Go or JavaScript you will need to deal with loops, functions, classes, error handling etc. and I don't see much advantage in it.

Maybe there are some special cases, where Pulumi can shine. I.e. when you have some custom logic, which you have to execute during the deployment, and it's hard to integrate when using other IaC tools. In this case using a general-purpose language could make sense.
Right now, I think for most cases dedicated IaC tools like Terraform, CloudFormation or ARM templates are enough. They are mature and have established communities.

## Read more

- https://www.pulumi.com/
- https://www.pulumi.com/docs/get-started/
- https://www.pulumi.com/docs/guides/crosswalk/aws/
- https://github.com/pulumi/examples
