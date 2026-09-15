defmodule GymStudioWeb.PageController do
  use GymStudioWeb, :controller

  # [LANDING-PAGE] Static branch data for landing page release - see #92
  # When re-enabling full features, replace @static_branches with DB lookup:
  #   alias GymStudio.Accounts
  #   alias GymStudio.Branches
  #   trainers = Accounts.list_approved_trainers() |> GymStudio.Repo.preload(user: [:branch])
  #   branches = Branches.list_branches(active: true)
  #   render(conn, :home, branches: branches, trainers: trainers)
  @static_branches [
    %{
      name: "Horsh Tabet",
      address: "Clover Park, 4th floor",
      phone: "+961 70 379 764",
      whatsapp_url:
        "https://wa.me/96170379764?text=Hello%2C%20can%20you%20tell%20me%20more%20about%20the%20service%20you%20provide%20at%20React%3F",
      directions_url: "https://www.google.com/maps/place/33.8709623,35.5343566",
      photos: [
        %{
          alt: "React Gym Horsh Tabet member performing kettlebell press",
          base: "/images/branches/horsh-tabet-kettlebell"
        }
      ]
    },
    %{
      name: "Jal El Dib",
      address: "Main Street",
      phone: "+961 71 633 970",
      whatsapp_url:
        "https://wa.me/96171633970?text=Hello%2C%20can%20you%20tell%20me%20more%20about%20the%20service%20you%20provide%20at%20React%3F",
      directions_url: "https://www.google.com/maps/place/33.9069,35.5801",
      photos: [
        %{
          alt: "React Gym Jal El Dib smiling client with trainer during stretching",
          base: "/images/branches/jal-el-dib-stretching"
        }
      ]
    }
  ]

  @static_testimonials [
    %{
      author: "Arline Atamian",
      text:
        "The best staff ever highly recommended. As a 60 year old person i feel my body is improving and if you are my age or even over it is never too late to start again!"
    },
    %{
      author: "Joseph Rehayem",
      text:
        "If you're looking for a gym with an amazing atmosphere, a team of friendly and supportive staff, and highly skilled trainers, then this is the perfect spot to achieve your fitness goals."
    },
    %{
      author: "Christelle Fawaz",
      text:
        "Friendliest staff, most caring and professional. As a pregnant woman i feel safe training with them."
    },
    %{
      author: "Youssef Khouzami",
      text: "A very friendly place with professional trainers…love it."
    },
    %{
      author: "Nader Abou Nader",
      text: "Amazing place with professional trainers!!"
    }
  ]

  # [LANDING-PAGE] Static trainer data, matching the branches and testimonials
  # above — the portal stays gated behind #92, so this avoids depending on
  # seeded records for a public page.
  #
  # No branch on the cards, by request: trainers move between studios and the
  # badge dates quickly.
  #
  # Specializations name what sets a trainer apart, so "Personal Training" is
  # not one — every trainer here does that. Leave the list empty rather than
  # filling it with the job title.
  #
  # The template skips both the bio and the specializations line when they are
  # absent, so a card with only a photo and a name still renders cleanly while
  # the rest of the roster is filled in.
  # Order is deliberate: Elio leads as founder and head of training, Lynn
  # second, and the rest follow in no particular ranking.
  @static_trainers [
    %{
      name: "Elio",
      slug: "elio",
      specializations: ["Founder", "Head of Training"],
      bio:
        "Elio is React's founder and head trainer. He holds a Bachelor's Degree in Physical Education and leads the training programme across both studios."
    },
    %{
      name: "Lynn",
      slug: "lynn",
      specializations: ["Post-Rehabilitation", "Special Populations"],
      bio:
        "Lynn has four years of experience in personal training, with a background in Physical Education. She holds certifications in Personal Training, Post-Rehabilitation, and Special Populations, and has worked with clients across a wide range of ages, fitness levels, and goals."
    },
    %{
      name: "Sandy",
      slug: "sandy",
      specializations: ["Athletic Training", "Post-Injury Rehabilitation"],
      bio:
        "Sandy trains athletes across all sports and age groups, and works with clients returning from injury of any kind. She studied personal training, strength and conditioning, and post-rehabilitation at Step Ahead Sports School, holds a management degree from USJ, and has four years in the field. Her continued study includes workshops in youth athletic development, applied sports science, and speed and agility."
    },
    %{
      name: "Mario",
      slug: "mario",
      specializations: ["Hybrid Training", "HYROX", "Calisthenics"],
      bio:
        "Certified Personal Trainer and HYROX Certified Coach specialising in hybrid training, combining running and strength work to balance physical performance with overall development. He has coached athletes for HYROX Paris and self-coached his own preparation for HYROX Turkey. He also teaches calisthenics fundamentals and progressive bodyweight training, helping clients build strength, control, and movement efficiency."
    },
    %{
      name: "Chris",
      slug: "chris",
      specializations: ["Strength & Conditioning", "Post-Injury Rehabilitation"],
      bio:
        "Chris is a strength and conditioning coach, CFSC certified at Levels 1 and 2, focusing on post-injury training and rehabilitation. He has been with React for a year and a half and has worked with Division 1 athletes and professional futsal and basketball players."
    },
    %{
      name: "Maroun",
      slug: "maroun",
      specializations: ["Sports Science", "Basketball", "Athletic Conditioning"],
      bio:
        "Maroun Naffaa is studying Sports Science at UA University and brings a competitive basketball background to his coaching. He has played for Chiyah Forum, Chabeb Zahle, and Damour, and currently plays for Beit Mery Basketball in Divisions 3 and 4. His training carries over the discipline and teamwork that competitive sport demands."
    }
  ]

  def home(conn, _params) do
    render(conn, :home,
      branches: @static_branches,
      testimonials: @static_testimonials,
      trainers: @static_trainers
    )
  end
end
